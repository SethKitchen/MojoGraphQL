# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/override.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.0 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.0 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.0 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.0 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.1 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.1 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.1 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.1 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.2 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.2 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.2 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.2 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.3 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.3 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.3 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.3 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.4 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.4 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.4 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.4 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.5 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.5 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.5 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.5 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.6 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.6 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.6 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.6 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.7 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.7 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.7 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.7 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.8 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.8 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.8 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.8 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_non_progressive_override_with_requires_source_keeps_current_implementation() raises:
    # v2.9 > non-progressive override with @requires source keeps current implementation behavior
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_deep_requires_override_prunes_stale_join_field_and_join_type() raises:
    # v2.9 > deep @requires override prunes stale @join__field and @join__type
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_nested_external_remains_when_another_requires_still_uses_it() raises:
    # v2.9 > nested external remains when another @requires still uses it
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCard { details { number cvv } }\")\n  fraudScore: Int! @shareable @requires(fields: \"creditCard { details { number } }\")\n}\n\nextend type CreditCard {\n  details: CreditCardDetails! @external\n}\n\nextend type CreditCardDetails {\n  number: String! @external\n  cvv: String! @external\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCard: CreditCard! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}\n\ntype CreditCard {\n  details: CreditCardDetails! @shareable\n}\n\ntype CreditCardDetails {\n  number: String! @shareable\n  cvv: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_overriding_one_source_graph_does_not_drop_external_usage_from_another_activ() raises:
    # v2.9 > overriding one source graph does not drop external usage from another active source
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "legacy",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  fraudScore: Int! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
