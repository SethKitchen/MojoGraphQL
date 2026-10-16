# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/REFERENCED_INACCESSIBLE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_referenced_inaccessible() raises:
    # v2.0 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_1_referenced_inaccessible() raises:
    # v2.1 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_2_referenced_inaccessible() raises:
    # v2.2 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_3_referenced_inaccessible() raises:
    # v2.3 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_4_referenced_inaccessible() raises:
    # v2.4 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_5_referenced_inaccessible() raises:
    # v2.5 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_6_referenced_inaccessible() raises:
    # v2.6 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_7_referenced_inaccessible() raises:
    # v2.7 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_8_referenced_inaccessible() raises:
    # v2.8 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def test_v2_9_referenced_inaccessible() raises:
    # v2.9 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users(filter: Filter, access: Access): [User]\n}\n\nenum Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype User @inaccessible {\n  id: ID!\n}\n\ninput Filter @inaccessible {\n  limit: Int\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile! @inaccessible\n}\n\ntype Profile {\n  name: String\n  address: Address\n}\n\ntype Address @inaccessible {\n  street: String\n  postalCode: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  products: [Product]\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ntype Query {\n  a: Foo\n}\n\nscalar Foo",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ntype Query {\n  b: String\n}\n\nscalar Foo @inaccessible",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
