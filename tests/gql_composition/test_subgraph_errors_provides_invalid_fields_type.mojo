# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/PROVIDES_INVALID_FIELDS_TYPE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_provides_invalid_fields_type_boolean() raises:
    # v2.0 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_1_provides_invalid_fields_type_boolean() raises:
    # v2.1 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_2_provides_invalid_fields_type_boolean() raises:
    # v2.2 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_3_provides_invalid_fields_type_boolean() raises:
    # v2.3 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_4_provides_invalid_fields_type_boolean() raises:
    # v2.4 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_5_provides_invalid_fields_type_boolean() raises:
    # v2.5 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_6_provides_invalid_fields_type_boolean() raises:
    # v2.6 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_7_provides_invalid_fields_type_boolean() raises:
    # v2.7 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_8_provides_invalid_fields_type_boolean() raises:
    # v2.8 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def test_v2_9_provides_invalid_fields_type_boolean() raises:
    # v2.9 > PROVIDES_INVALID_FIELDS_TYPE - boolean
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
        ],
        [
            (
                "[PROVIDES_INVALID_FIELDS_TYPE] [billing] On field"
                ' "Invoice.payment", for @provides(fields: true): Invalid value'
                ' for argument "fields": must be a string.'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
