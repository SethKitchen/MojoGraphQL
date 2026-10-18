# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE_PROGRESSIVE_REQUIRES.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive
`OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE` from `composeServices` on
the same subgraphs. The last test locks a labeled `@override` whose
source field has no `@requires`. It is not in the upstream file.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_7_override_collision_with_another_directive_for_progressive_override_with_req() raises:
    # v2.7 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE for progressive override with @requires
    check(
        [
            sg(
                "original",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires", "@shareable"])\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n '
                    " creditCardNumber: String! @external\n  paymentReceipt:"
                    " String! @shareable @requires(fields:"
                    ' "creditCardNumber")\n}\n\ntype Query {\n  product(id:'
                    " ID!): Product\n}"
                ),
            ),
            sg(
                "new",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  creditCardNumber:'
                    " String! @shareable\n  paymentReceipt: String! @shareable"
                    ' @override(from: "original", label: "public")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] @override with"
                " label (progressive override) cannot be used on field"
                ' "Product.paymentReceipt" on subgraph "new" since'
                ' "Product.paymentReceipt" on "original" is marked with'
                ' directive "@requires". Use non-progressive @override (without'
                " label) for this migration."
            ),
        ],
    )


def test_v2_8_override_collision_with_another_directive_for_progressive_override_with_req() raises:
    # v2.8 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE for progressive override with @requires
    check(
        [
            sg(
                "original",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires", "@shareable"])\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n '
                    " creditCardNumber: String! @external\n  paymentReceipt:"
                    " String! @shareable @requires(fields:"
                    ' "creditCardNumber")\n}\n\ntype Query {\n  product(id:'
                    " ID!): Product\n}"
                ),
            ),
            sg(
                "new",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  creditCardNumber:'
                    " String! @shareable\n  paymentReceipt: String! @shareable"
                    ' @override(from: "original", label: "public")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] @override with"
                " label (progressive override) cannot be used on field"
                ' "Product.paymentReceipt" on subgraph "new" since'
                ' "Product.paymentReceipt" on "original" is marked with'
                ' directive "@requires". Use non-progressive @override (without'
                " label) for this migration."
            ),
        ],
    )


def test_v2_9_override_collision_with_another_directive_for_progressive_override_with_req() raises:
    # v2.9 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE for progressive override with @requires
    check(
        [
            sg(
                "original",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires", "@shareable"])\n\ntype'
                    ' Product @key(fields: "id") {\n  id: ID!\n '
                    " creditCardNumber: String! @external\n  paymentReceipt:"
                    " String! @shareable @requires(fields:"
                    ' "creditCardNumber")\n}\n\ntype Query {\n  product(id:'
                    " ID!): Product\n}"
                ),
            ),
            sg(
                "new",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  creditCardNumber:'
                    " String! @shareable\n  paymentReceipt: String! @shareable"
                    ' @override(from: "original", label: "public")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] @override with"
                " label (progressive override) cannot be used on field"
                ' "Product.paymentReceipt" on subgraph "new" since'
                ' "Product.paymentReceipt" on "original" is marked with'
                ' directive "@requires". Use non-progressive @override (without'
                " label) for this migration."
            ),
        ],
    )


def test_a_labeled_override_without_requires_is_valid() raises:
    # The source field has no `@requires`, so the label is allowed.
    check(
        [
            sg(
                "original",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Product @key(fields:'
                    ' "id") {\n  id: ID!\n  paymentReceipt: String!'
                    " @shareable\n}\n\ntype Query {\n  product(id: ID!):"
                    " Product\n}"
                ),
            ),
            sg(
                "new",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  paymentReceipt:'
                    ' String! @shareable @override(from: "original", label:'
                    ' "public")\n}'
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
