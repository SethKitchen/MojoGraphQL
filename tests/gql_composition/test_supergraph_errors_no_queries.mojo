# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/NO_QUERIES.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_no_queries() raises:
    # v2.0 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_no_queries() raises:
    # v2.1 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_no_queries() raises:
    # v2.2 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_no_queries() raises:
    # v2.3 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_no_queries() raises:
    # v2.4 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_no_queries() raises:
    # v2.5 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_no_queries() raises:
    # v2.6 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_no_queries() raises:
    # v2.7 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_no_queries() raises:
    # v2.8 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_no_queries() raises:
    # v2.9 > NO_QUERIES
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\nschema {\n  query: RootQuery\n}\n\ntype"
                    " RootQuery {\n  users: [User]\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
