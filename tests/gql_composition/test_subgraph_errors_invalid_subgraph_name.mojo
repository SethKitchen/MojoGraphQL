# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/INVALID_SUBGRAPH_NAME.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_invalid_subgraph_name() raises:
    # v2.0 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_1_invalid_subgraph_name() raises:
    # v2.1 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_2_invalid_subgraph_name() raises:
    # v2.2 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_3_invalid_subgraph_name() raises:
    # v2.3 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_4_invalid_subgraph_name() raises:
    # v2.4 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_5_invalid_subgraph_name() raises:
    # v2.5 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_6_invalid_subgraph_name() raises:
    # v2.6 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_7_invalid_subgraph_name() raises:
    # v2.7 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_8_invalid_subgraph_name() raises:
    # v2.8 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def test_v2_9_invalid_subgraph_name() raises:
    # v2.9 > INVALID_SUBGRAPH_NAME
    check(
        [
            sg(
                "_",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_SUBGRAPH_NAME] [_] Invalid name _ for a subgraph:"
                " this name is reserved"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
