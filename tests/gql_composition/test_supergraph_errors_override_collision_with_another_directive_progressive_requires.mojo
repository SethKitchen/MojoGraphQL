# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE_PROGRESSIVE_REQUIRES.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_7_override_collision_with_another_directive_for_progressive_override_with_req() raises:
    # v2.7 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE for progressive override with @requires
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\", label: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_override_collision_with_another_directive_for_progressive_override_with_req() raises:
    # v2.8 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE for progressive override with @requires
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\", label: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_override_collision_with_another_directive_for_progressive_override_with_req() raises:
    # v2.9 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE for progressive override with @requires
    check(
        [
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\", label: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
