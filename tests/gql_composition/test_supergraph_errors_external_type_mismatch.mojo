# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/EXTERNAL_TYPE_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors include Hive `EXTERNAL_TYPE_MISMATCH` from
`composeServices` on the same subgraphs. A field-type error comes first.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_external_type_mismatch() raises:
    # v2.0 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.0 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_1_external_type_mismatch() raises:
    # v2.1 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.1 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_2_external_type_mismatch() raises:
    # v2.2 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.2 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_3_external_type_mismatch() raises:
    # v2.3 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.3 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_4_external_type_mismatch() raises:
    # v2.4 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.4 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_5_external_type_mismatch() raises:
    # v2.5 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.5 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_6_external_type_mismatch() raises:
    # v2.6 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.6 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_7_external_type_mismatch() raises:
    # v2.7 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.7 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_8_external_type_mismatch() raises:
    # v2.8 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.8 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_v2_9_external_type_mismatch() raises:
    # v2.9 > EXTERNAL_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  tags:'
                    " [String!]\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Query {\n '
                    ' feed: [Article]\n}\n\ntype Article @key(fields: "id") {\n'
                    "  id: ID!\n  author: User! @provides(fields:"
                    ' "tags")\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID!\n  tags: [String]! @external\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.tags" is'
                ' incompatible across subgraphs: it has type "[String]!" in'
                ' subgraph "feed" but type "[String!]" in subgraph "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.tags" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "[String!]" in subgraph "users" but type "[String]!"'
                ' in subgraph "feed"'
            ),
        ],
    )
    check(
        [
            sg(
                "scores",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    ' @external\n  score: Int! @requires(fields: "name")\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "comments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @external\n  comments: [String!]! @requires(fields:"
                    ' "name")\n}'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "comments" but type "String!" in subgraphs "scores",'
                ' "users"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "String!" in subgraphs "scores" and "users" but type'
                ' "String" in subgraph "comments"'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n}\n\nextend'
                    ' type Component @key(fields: "context { id }") {\n '
                    " context: Context! @external\n}\n\ntype Context {\n  id:"
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n  id: ID'
                    " @external\n  age: Int\n}\n\ntype Context {\n  id:"
                    ' ID!\n}\n\ntype Component @key(fields: "context { id }")'
                    " {\n  context: Context\n  id: ID!\n}"
                ),
            ),
            sg(
                "c",
                (
                    'extend type User @key(fields: "id") {\n  id: ID!'
                    " @external\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_external_type_mismatch_on_a_field_selected_by_requires() raises:
    # v2.9 > EXTERNAL_TYPE_MISMATCH on a field selected by @requires
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  product: Product\n}\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n  variant:'
                    ' VariantV1!\n}\n\ntype VariantV1 @key(fields: "id") {\n '
                    " id: ID!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  variant: VariantV2'
                    ' @external\n  price: Float @requires(fields: "variant {'
                    ' sku }")\n}\n\ntype VariantV2 @key(fields: "id") {\n  id:'
                    " ID!\n  sku: String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Product.variant" is'
                ' incompatible across subgraphs: it has type "VariantV2" in'
                ' subgraph "pricing" but type "VariantV1!" in subgraph'
                ' "products"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "Product.variant" is'
                " incompatible across subgraphs (where marked @external): it"
                ' has type "VariantV1!" in subgraph "products" but type'
                ' "VariantV2" in subgraph "pricing"'
            ),
        ],
    )


def test_hive_case_et1() raises:
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
                    '","@context","@fromContext"])\ntype Query { u: User'
                    ' }\ntype User @key(fields: "id") { id: ID! name: String }'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! name: Int @external x: String'
                    ' @requires(fields: "name") }'
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! name: Boolean @external y: String'
                    ' @requires(fields: "name") }'
                ),
            ),
            sg(
                "d",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! name: Int @external z: String'
                    ' @requires(fields: "name") }'
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "a" but type "Int" in subgraphs "b", "d" and'
                ' type "Boolean" in subgraph "c"'
            ),
            (
                '[EXTERNAL_TYPE_MISMATCH] Type of field "User.name" is'
                " incompatible across subgraphs (where marked @external):"
                ' it has type "String" in subgraph "a" but type "Int" in'
                ' subgraphs "b" and "d" and type "Boolean" in subgraph'
                ' "c"'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
