# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/REQUIRED_INACCESSIBLE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_required_inaccessible() raises:
    # v2.0 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_required_inaccessible() raises:
    # v2.1 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_required_inaccessible() raises:
    # v2.2 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_required_inaccessible() raises:
    # v2.3 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_required_inaccessible() raises:
    # v2.4 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_required_inaccessible() raises:
    # v2.5 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_required_inaccessible() raises:
    # v2.6 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_required_inaccessible() raises:
    # v2.7 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_required_inaccessible() raises:
    # v2.8 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_required_inaccessible() raises:
    # v2.9 > REQUIRED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ninput A {\n  id: ID! @inaccessible\n  b: Int\n}\n\ntype Query {\n  a(a: A): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: ID! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ninput A @inaccessible {\n  a: Int! @inaccessible\n}\n\ntype Query {\n  a(id: A! @inaccessible): Int! @inaccessible\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ntype Query {\n  a(id: String! = \"brrry\" @inaccessible): Int!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ninput Foo {\n  a: String\n  b: String! = \"he he he\" @inaccessible\n}\n\ntype Query {\n  a(id: Foo!): Int!\n  b: Int!\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
