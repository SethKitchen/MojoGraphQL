# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/KEY_FIELDS_SELECT_INVALID_TYPE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_key_fields_select_invalid_type() raises:
    # v2.0 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_1_key_fields_select_invalid_type() raises:
    # v2.1 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_2_key_fields_select_invalid_type() raises:
    # v2.2 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_3_key_fields_select_invalid_type() raises:
    # v2.3 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_4_key_fields_select_invalid_type() raises:
    # v2.4 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_5_key_fields_select_invalid_type() raises:
    # v2.5 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_6_key_fields_select_invalid_type() raises:
    # v2.6 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_7_key_fields_select_invalid_type() raises:
    # v2.7 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_8_key_fields_select_invalid_type() raises:
    # v2.8 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def test_v2_9_key_fields_select_invalid_type() raises:
    # v2.9 > KEY_FIELDS_SELECT_INVALID_TYPE
    check(
        [
            sg(
                "serviceA",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"featuredItem { id }\") {\n  featuredItem: Node!\n  sku: String!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "serviceB",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@external\", \"@requires\"])\n\nextend type Product {\n  sku: String! @external\n  price: Int! @requires(fields: \"sku\")\n}",
            ),
        ],
        [
            "[KEY_FIELDS_SELECT_INVALID_TYPE] [serviceA] On type \"Product\", for @key(fields: \"featuredItem { id }\"): field \"Product.featuredItem\" is a Interface type which is not allowed in @key",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
