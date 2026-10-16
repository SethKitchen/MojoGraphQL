# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_merged_directive_application_on_external() raises:
    # v2.0 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_0_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.0 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merged_directive_application_on_external() raises:
    # v2.1 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_1_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.1 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merged_directive_application_on_external() raises:
    # v2.2 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_2_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.2 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merged_directive_application_on_external() raises:
    # v2.3 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_3_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.3 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merged_directive_application_on_external() raises:
    # v2.4 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_4_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.4 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merged_directive_application_on_external() raises:
    # v2.5 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_5_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.5 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merged_directive_application_on_external() raises:
    # v2.6 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_6_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.6 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merged_directive_application_on_external() raises:
    # v2.7 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_7_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.7 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merged_directive_application_on_external() raises:
    # v2.8 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_8_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.8 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merged_directive_application_on_external() raises:
    # v2.9 > MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_9_fed_v1_has_no_merged_directive_application_on_external() raises:
    # v2.9 > Fed v1 has no MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL
    check(
        [
            sg(
                "inventory",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @tag(name: \"public\")\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float @tag(name: \"public\")\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n}",
            ),
            sg(
                "ext",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Product @key(fields: \"id\") @key(fields: \"sku package\") {\n  id: ID!\n  sku: String\n  package: String\n  dimensions: ProductDimension\n}\n\ntype ProductDimension {\n  size: String\n  weight: Float\n}\n\ntype Query {\n  allProducts: [Product]\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
