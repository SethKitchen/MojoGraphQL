# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_interface_key_missing_implementation_type() raises:
    # v2.0 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.0 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )


def test_v2_0_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.0 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_interface_key_missing_implementation_type() raises:
    # v2.1 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.1 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )


def test_v2_1_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.1 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_interface_key_missing_implementation_type() raises:
    # v2.2 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.2 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
            "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
            "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on interface \"User\": @key is not yet supported on interfaces",
        ],
    )


def test_v2_2_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.2 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_interface_key_missing_implementation_type() raises:
    # v2.3 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.3 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.3 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_interface_key_missing_implementation_type() raises:
    # v2.4 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.4 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.4 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_interface_key_missing_implementation_type() raises:
    # v2.5 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.5 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.5 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_interface_key_missing_implementation_type() raises:
    # v2.6 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.6 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.6 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_interface_key_missing_implementation_type() raises:
    # v2.7 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.7 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.7 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_interface_key_missing_implementation_type() raises:
    # v2.8 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.8 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.8 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_interface_key_missing_implementation_type() raises:
    # v2.9 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\nextend interface Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype User implements Node @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.9 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  users: [User]\n}\n\ninterface User @key(fields: \"email\") @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype RegisteredUser implements User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") @key(fields: \"email\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
            sg(
                "blocked",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype BlockedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}\n\nextend interface User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.9 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Node @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
