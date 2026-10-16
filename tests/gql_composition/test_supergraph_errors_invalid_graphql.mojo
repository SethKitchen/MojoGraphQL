# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/INVALID-GRAPHQL.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_interface_field_object_field_subtype() raises:
    # v2.0 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_interface_field_object_field_subtype() raises:
    # v2.1 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_interface_field_object_field_subtype() raises:
    # v2.2 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_interface_field_object_field_subtype() raises:
    # v2.3 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_interface_field_object_field_subtype() raises:
    # v2.4 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_interface_field_object_field_subtype() raises:
    # v2.5 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_interface_field_object_field_subtype() raises:
    # v2.6 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_interface_field_object_field_subtype() raises:
    # v2.7 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_interface_field_object_field_subtype() raises:
    # v2.8 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_interface_field_object_field_subtype() raises:
    # v2.9 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n}\n\ntype User implements Node {\n  id: ID!\n}\n\ninterface Node {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  b: Admin\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin implements Node {\n  id: ID! @shareable\n  parent: Node\n}\n\ntype User implements Node {\n  id: ID!\n  parent: User\n}\n\ninterface Node {\n  id: ID!\n  parent: Node\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
