# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/TYPE_KIND_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_type_kind_mismatch() raises:
    # v2.0 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_type_kind_mismatch() raises:
    # v2.1 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_type_kind_mismatch() raises:
    # v2.2 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_type_kind_mismatch() raises:
    # v2.3 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_type_kind_mismatch() raises:
    # v2.4 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_type_kind_mismatch() raises:
    # v2.5 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_type_kind_mismatch() raises:
    # v2.6 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_type_kind_mismatch() raises:
    # v2.7 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_type_kind_mismatch() raises:
    # v2.8 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_type_kind_mismatch() raises:
    # v2.9 > TYPE_KIND_MISMATCH
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  usernames: [String!]!\n}\n\ntype User {\n  id: ID!\n}",
            ),
            sg(
                "friends",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nextend interface User {\n  id: ID!\n  friends: [User!]!\n}",
            ),
            sg(
                "pets",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ninput Pet {\n  name: String!\n}\n\nextend input User {\n  id: ID!\n  pets: [Pet!]!\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
