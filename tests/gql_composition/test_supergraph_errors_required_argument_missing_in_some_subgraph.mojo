# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive
`REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH` from `composeServices` on
the same subgraphs. A sharing error that Hive reports for the same
subgraphs comes first.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_required_argument_missing_in_some_subgraph() raises:
    # v2.0 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_1_required_argument_missing_in_some_subgraph() raises:
    # v2.1 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_2_required_argument_missing_in_some_subgraph() raises:
    # v2.2 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_3_required_argument_missing_in_some_subgraph() raises:
    # v2.3 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_4_required_argument_missing_in_some_subgraph() raises:
    # v2.4 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_5_required_argument_missing_in_some_subgraph() raises:
    # v2.5 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_6_required_argument_missing_in_some_subgraph() raises:
    # v2.6 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_7_required_argument_missing_in_some_subgraph() raises:
    # v2.7 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_8_required_argument_missing_in_some_subgraph() raises:
    # v2.8 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def test_v2_9_required_argument_missing_in_some_subgraph() raises:
    # v2.9 > REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  user(id: Int!):'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  user:'
                    ' User!\n}\n\ntype User @key(fields: "id") {\n  id: Int!'
                    " @external\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.user" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                "[REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH] Argument"
                ' "Query.user(id:)" is required in some subgraphs but does not'
                ' appear in all subgraphs: it is required in subgraph "users"'
                ' but does not appear in subgraph "feed"'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
