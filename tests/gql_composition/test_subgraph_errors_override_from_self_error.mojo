# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/OVERRIDE_FROM_SELF_ERROR.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_override_from_self_error() raises:
    # v2.0 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_1_override_from_self_error() raises:
    # v2.1 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_2_override_from_self_error() raises:
    # v2.2 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_3_override_from_self_error() raises:
    # v2.3 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_4_override_from_self_error() raises:
    # v2.4 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_5_override_from_self_error() raises:
    # v2.5 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_6_override_from_self_error() raises:
    # v2.6 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_7_override_from_self_error() raises:
    # v2.7 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_8_override_from_self_error() raises:
    # v2.8 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def test_v2_9_override_from_self_error() raises:
    # v2.9 > OVERRIDE_FROM_SELF_ERROR
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  bills:'
                    ' [Bill]\n}\n\ntype Bill @key(fields: "id") {\n  id: ID!\n '
                    ' amount: Int! @override(from: "billing")\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination"
                ' subgraphs "billing" are the same for overridden field'
                ' "Bill.amount"'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
