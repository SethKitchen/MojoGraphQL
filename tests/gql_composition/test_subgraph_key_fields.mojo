# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/key-fields.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_typename_allowed_in_provides() raises:
    # v2.0 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_typename_allowed_in_requires() raises:
    # v2.0 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_0_fragments_in_requires() raises:
    # v2.0 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_missing_fieldset_definition() raises:
    # v2.0 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_1_typename_allowed_in_provides() raises:
    # v2.1 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_typename_allowed_in_requires() raises:
    # v2.1 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_1_fragments_in_requires() raises:
    # v2.1 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_missing_fieldset_definition() raises:
    # v2.1 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_2_typename_allowed_in_provides() raises:
    # v2.2 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_typename_allowed_in_requires() raises:
    # v2.2 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_2_fragments_in_requires() raises:
    # v2.2 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_missing_fieldset_definition() raises:
    # v2.2 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_3_typename_allowed_in_provides() raises:
    # v2.3 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_typename_allowed_in_requires() raises:
    # v2.3 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_3_fragments_in_requires() raises:
    # v2.3 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_missing_fieldset_definition() raises:
    # v2.3 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_4_typename_allowed_in_provides() raises:
    # v2.4 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_typename_allowed_in_requires() raises:
    # v2.4 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_4_fragments_in_requires() raises:
    # v2.4 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_missing_fieldset_definition() raises:
    # v2.4 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_5_typename_allowed_in_provides() raises:
    # v2.5 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_typename_allowed_in_requires() raises:
    # v2.5 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_5_fragments_in_requires() raises:
    # v2.5 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_missing_fieldset_definition() raises:
    # v2.5 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_6_typename_allowed_in_provides() raises:
    # v2.6 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_typename_allowed_in_requires() raises:
    # v2.6 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_6_fragments_in_requires() raises:
    # v2.6 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_missing_fieldset_definition() raises:
    # v2.6 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_7_typename_allowed_in_provides() raises:
    # v2.7 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_typename_allowed_in_requires() raises:
    # v2.7 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_7_fragments_in_requires() raises:
    # v2.7 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_missing_fieldset_definition() raises:
    # v2.7 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_8_typename_allowed_in_provides() raises:
    # v2.8 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_typename_allowed_in_requires() raises:
    # v2.8 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_fragments_in_requires() raises:
    # v2.8 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_missing_fieldset_definition() raises:
    # v2.8 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def test_v2_9_typename_allowed_in_provides() raises:
    # v2.9 > __typename allowed in @provides
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @shareable\n}\n\ntype Profile {\n  id:"
                    " ID! @shareable\n  name: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@provides", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author: User!"
                    ' @provides(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n}\n\nextend"
                    " type Profile {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_typename_allowed_in_requires() raises:
    # v2.9 > __typename allowed in @requires
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  profile:'
                    " Profile!\n}\n\ntype Profile {\n  id: ID!\n  name:"
                    " String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n '
                    ' reviews: [Review]\n}\n\ntype Review @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n  author:"
                    ' User!\n}\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID! @external\n  profile: Profile! @external\n  reviews:"
                    ' [Review] @requires(fields: "profile { id __typename'
                    ' }")\n}\n\nextend type Profile {\n  id: ID! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_fragments_in_requires() raises:
    # v2.9 > fragments in @requires
    check(
        [
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@requires"])\n\ntype'
                    ' Product implements ProductItf @key(fields: "id") {\n  id:'
                    " ID!\n  dimensions: ProductDimension @external\n "
                    " delivery(zip: String): DeliveryEstimates"
                    ' @requires(fields: "dimensions { ... on ProductDimension {'
                    ' size weight } }")\n}\n\ntype ProductDimension @shareable'
                    " {\n  size: String\n  weight: Float\n}\n\ntype"
                    " DeliveryEstimates {\n  estimatedDelivery: String\n "
                    " fastestDelivery: String\n}\n\ninterface ProductItf {\n "
                    " id: ID!\n  dimensions: ProductDimension\n  delivery(zip:"
                    " String): DeliveryEstimates\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n  OVERNIGHT\n}"
                ),
            ),
            sg(
                "pandas",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n "
                    " panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n"
                    '  favoriteFood: String @tag(name: "nom-nom-nom")\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/myDirective/v1.0", import:'
                    ' ["@myDirective", {name: "@anotherDirective", as:'
                    ' "@hello"}]) @composeDirective(name: "@myDirective")'
                    ' @composeDirective(name: "@hello")\n\ndirective'
                    " @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective"
                    " @hello on FIELD_DEFINITION\n\ntype Query {\n "
                    " allProducts: [ProductItf]\n  product(id: ID!):"
                    " ProductItf\n}\n\ninterface ProductItf implements SkuItf"
                    " {\n  id: ID!\n  sku: String\n  name: String\n  package:"
                    " String\n  variation: ProductVariation\n  dimensions:"
                    " ProductDimension\n  createdBy: User\n  hidden: String"
                    " @inaccessible\n  oldField: String @deprecated(reason:"
                    ' "refactored out")\n}\n\ninterface SkuItf {\n  sku:'
                    " String\n}\n\ntype Product implements ProductItf & SkuItf"
                    ' @key(fields: "id") @key(fields: "sku package")'
                    ' @key(fields: "sku variation { id }") {\n  id: ID!'
                    ' @tag(name: "hi-from-products")\n  sku: String\n  name:'
                    " String @hello\n  package: String\n  variation:"
                    " ProductVariation\n  dimensions: ProductDimension\n "
                    " createdBy: User\n  hidden: String\n  reviewsScore:"
                    " Float!\n  oldField: String\n}\n\nenum ShippingClass {\n "
                    " STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id:"
                    " ID!\n  name: String\n}\n\ntype ProductDimension"
                    " @shareable {\n  size: String\n  weight: Float\n}\n\ntype"
                    ' User @key(fields: "email") {\n  email: ID!\n '
                    " totalProductsCreated: Int @shareable\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@shareable"]) {\n  query:'
                    " Query\n}\n\ntype Product implements ProductItf"
                    ' @key(fields: "id") {\n  id: ID!\n  reviewsCount: Int!\n '
                    " reviewsScore: Float! @shareable @override(from:"
                    ' "products")\n  reviews: [Review!]!\n}\n\ninterface'
                    " ProductItf {\n  id: ID!\n  reviewsCount: Int!\n "
                    " reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype"
                    " Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n"
                    "  id: Int!\n  body: String!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "directive @tag(name: String!) repeatable on"
                    " FIELD_DEFINITION | OBJECT\n\ntype User @key(fields:"
                    ' "email") {\n  email: ID! @tag(name: "test-from-users")\n '
                    " name: String\n  totalProductsCreated: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_missing_fieldset_definition() raises:
    # v2.9 > missing _FieldSet definition
    check(
        [
            sg(
                "foo",
                (
                    "directive @key(fields: _FieldSet!) repeatable on OBJECT |"
                    " INTERFACE\n\ntype Query {\n  users: [User]\n}\n\ntype"
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [foo] Unknown type _FieldSet",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
