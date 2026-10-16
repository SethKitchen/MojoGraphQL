# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/INVALID_SHAREABLE_USAGE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_invalid_shareable_usage() raises:
    # v2.0 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_1_invalid_shareable_usage() raises:
    # v2.1 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_2_invalid_shareable_usage() raises:
    # v2.2 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_3_invalid_shareable_usage() raises:
    # v2.3 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_4_invalid_shareable_usage() raises:
    # v2.4 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_5_invalid_shareable_usage() raises:
    # v2.5 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_6_invalid_shareable_usage() raises:
    # v2.6 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_7_invalid_shareable_usage() raises:
    # v2.7 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_8_invalid_shareable_usage() raises:
    # v2.8 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def test_v2_9_invalid_shareable_usage() raises:
    # v2.9 > INVALID_SHAREABLE_USAGE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User implements Node {\n  id: ID!\n  name: String\n}\n\ninterface Node {\n  id: ID! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
            "[INVALID_SHAREABLE_USAGE] [users] Invalid use of @shareable on field \"Node.id\": only object type fields can be marked with @shareable",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
