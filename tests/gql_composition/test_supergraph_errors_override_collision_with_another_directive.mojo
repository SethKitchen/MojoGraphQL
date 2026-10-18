# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_override_collision_with_another_directive() raises:
    # v2.0 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_1_override_collision_with_another_directive() raises:
    # v2.1 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_2_override_collision_with_another_directive() raises:
    # v2.2 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_3_override_collision_with_another_directive() raises:
    # v2.3 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_4_override_collision_with_another_directive() raises:
    # v2.4 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_5_override_collision_with_another_directive() raises:
    # v2.5 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_6_override_collision_with_another_directive() raises:
    # v2.6 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_7_override_collision_with_another_directive() raises:
    # v2.7 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_8_override_collision_with_another_directive() raises:
    # v2.8 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def test_v2_9_override_collision_with_another_directive() raises:
    # v2.9 > OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override", "@external",'
                    ' "@provides"])\n\nextend type Payment @key(fields: "id")'
                    ' {\n  id: ID!\n  amount: Int! @override(from: "payments")'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment @provides(fields:"
                    ' "amount")\n}'
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  payments:'
                    ' [Payment]\n}\n\ntype Payment @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n}"
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE] [billing]"
                ' @override cannot be used on field "Payment.amount" on'
                ' subgraph "billing" since "Payment.amount" on "billing" is'
                ' marked with directive "@external"'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
