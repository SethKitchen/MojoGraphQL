# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/IMPLEMENTED_BY_INACCESSIBLE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_implemented_by_inaccessible() raises:
    # v2.0 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_implemented_by_inaccessible() raises:
    # v2.1 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_implemented_by_inaccessible() raises:
    # v2.2 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_implemented_by_inaccessible() raises:
    # v2.3 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_implemented_by_inaccessible() raises:
    # v2.4 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_implemented_by_inaccessible() raises:
    # v2.5 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_implemented_by_inaccessible() raises:
    # v2.6 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_implemented_by_inaccessible() raises:
    # v2.7 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_implemented_by_inaccessible() raises:
    # v2.8 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_implemented_by_inaccessible() raises:
    # v2.9 > IMPLEMENTED_BY_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n}\n\ntype A implements Shared {\n  sharedField: String! @inaccessible\n  b: String!\n}\n\ntype B implements Shared {\n  sharedField: String!\n  b: String!\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ninterface Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype A implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype B implements Shared {\n  sharedField: String!\n  inaccessibleField: String! @inaccessible\n}\n\ntype Query {\n  a: Shared\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "node",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  b(id: ID! @federation__inaccessible): B @federation__inaccessible\n  a(id: ID!): A\n}\n\ntype B implements Node @federation__inaccessible {\n  id: ID! @federation__inaccessible\n}\n\ntype A implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
