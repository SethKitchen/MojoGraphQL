# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/OVERRIDE_SOURCE_HAS_OVERRIDE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_override_source_has_override() raises:
    # v2.0 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_override_source_has_override() raises:
    # v2.1 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_override_source_has_override() raises:
    # v2.2 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_override_source_has_override() raises:
    # v2.3 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_override_source_has_override() raises:
    # v2.4 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_override_source_has_override() raises:
    # v2.5 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_override_source_has_override() raises:
    # v2.6 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_override_source_has_override() raises:
    # v2.7 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_override_source_has_override() raises:
    # v2.8 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_override_source_has_override() raises:
    # v2.9 > OVERRIDE_SOURCE_HAS_OVERRIDE
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"payments\")\n}",
            ),
            sg(
                "payments",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  payments: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
            sg(
                "invoices",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\"])\n\ntype Query {\n  invoices: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\", \"@override\"])\n\ntype Query {\n  user: String @shareable @override(from: \"mono\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Query {\n  user: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
