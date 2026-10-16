# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/REQUIRES_FIELDS_MISSING_EXTERNAL.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_() raises:
    # 
    check(
        [
            sg(
                "users",
                "type Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_requires_fields_missing_external() raises:
    # v2.0 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_1_requires_fields_missing_external() raises:
    # v2.1 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_2_requires_fields_missing_external() raises:
    # v2.2 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_3_requires_fields_missing_external() raises:
    # v2.3 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_4_requires_fields_missing_external() raises:
    # v2.4 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_5_requires_fields_missing_external() raises:
    # v2.5 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_6_requires_fields_missing_external() raises:
    # v2.6 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_7_requires_fields_missing_external() raises:
    # v2.7 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_8_requires_fields_missing_external() raises:
    # v2.8 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def test_v2_9_requires_fields_missing_external() raises:
    # v2.9 > REQUIRES_FIELDS_MISSING_EXTERNAL
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@requires\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID!\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
        ],
        [
            "[REQUIRES_FIELDS_MISSING_EXTERNAL] [users] On field \"User.profile\", for @requires(fields: \"internalId\"): field \"User.internalId\" should not be part of a @requires since it is already provided by this subgraph (it is not marked @external)",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
