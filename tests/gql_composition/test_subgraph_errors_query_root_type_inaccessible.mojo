# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/QUERY_ROOT_TYPE_INACCESSIBLE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_query_root_type_inaccessible() raises:
    # v2.0 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_1_query_root_type_inaccessible() raises:
    # v2.1 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_2_query_root_type_inaccessible() raises:
    # v2.2 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_3_query_root_type_inaccessible() raises:
    # v2.3 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_4_query_root_type_inaccessible() raises:
    # v2.4 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_5_query_root_type_inaccessible() raises:
    # v2.5 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_6_query_root_type_inaccessible() raises:
    # v2.6 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_7_query_root_type_inaccessible() raises:
    # v2.7 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_8_query_root_type_inaccessible() raises:
    # v2.8 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def test_v2_9_query_root_type_inaccessible() raises:
    # v2.9 > QUERY_ROOT_TYPE_INACCESSIBLE
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible"])\n\nextend schema {\n  query:'
                    " RootQuery\n}\n\ntype RootQuery @inaccessible {\n  words:"
                    " [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query @inaccessible'
                    " {\n  words: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[QUERY_ROOT_TYPE_INACCESSIBLE] [book] Type "Query" is'
                " @inaccessible but is the root query type, which must be in"
                " the API schema."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
