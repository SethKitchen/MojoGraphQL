# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/join.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_join_spec_version_guild_federation_s_join_s() raises:
    # join spec version > guild > Federation %s == Join %s
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0,v0.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.0,v0.3 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1,v0.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.1,v0.3 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2,v0.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.2,v0.3 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3,v0.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.3,v0.3 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4,v0.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.4,v0.3 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5,v0.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.5,v0.3 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6,v0.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.6,v0.3 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7,v0.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.7,v0.4 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8,v0.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.8,v0.5 for the federation feature in @link directive on schema",
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9,v0.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.9,v0.5 for the federation feature in @link directive on schema",
        ],
    )


def test_join_spec_version_guild_federation_v1_0_join_v0_3() raises:
    # join spec version > guild > Federation v1.0 == Join v0.3
    check(
        [
            sg(
                "a",
                "type User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
