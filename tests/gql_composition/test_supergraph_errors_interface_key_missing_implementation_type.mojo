# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors include Hive `INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE`
from `composeServices` on the same subgraphs. Federation versions before
`v2.3` still report the subgraph `@key` error and do not reach this rule.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_interface_key_missing_implementation_type() raises:
    # v2.0 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.0 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )


def test_v2_0_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.0 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_interface_key_missing_implementation_type() raises:
    # v2.1 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.1 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )


def test_v2_1_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.1 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_interface_key_missing_implementation_type() raises:
    # v2.2 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.2 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [blocked] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [extra] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
            (
                "[KEY_UNSUPPORTED_ON_INTERFACE] [users] Cannot use @key on"
                ' interface "User": @key is not yet supported on interfaces'
            ),
        ],
    )


def test_v2_2_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.2 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_interface_key_missing_implementation_type() raises:
    # v2.3 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.3 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "email")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )


def test_v2_3_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.3 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_interface_key_missing_implementation_type() raises:
    # v2.4 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.4 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "email")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )


def test_v2_4_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.4 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_interface_key_missing_implementation_type() raises:
    # v2.5 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.5 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "email")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )


def test_v2_5_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.5 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_interface_key_missing_implementation_type() raises:
    # v2.6 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.6 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "email")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )


def test_v2_6_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.6 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_interface_key_missing_implementation_type() raises:
    # v2.7 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.7 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "email")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )


def test_v2_7_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.7 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_interface_key_missing_implementation_type() raises:
    # v2.8 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.8 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "email")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )


def test_v2_8_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.8 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_interface_key_missing_implementation_type() raises:
    # v2.9 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  a: String\n}\n\nextend interface Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  b: String\n}\n\ninterface Node {\n  id:"
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_interface_key_missing_implementation_type_multiple_keys() raises:
    # v2.9 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: multiple keys
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "email")'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}"
                ),
            ),
            sg(
                "extra",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype RegisteredUser implements User'
                    ' @key(fields: "id") @key(fields: "email") {\n  id: ID!\n '
                    " name: String!\n  email: String\n}\n\nextend interface"
                    ' User @key(fields: "id") @key(fields: "email") {\n  id:'
                    " ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "blocked",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype BlockedUser implements User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!\n '
                    " email: String\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n  email: String\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [blocked]"
                ' Interface type "User" has a resolvable key (@key(fields:'
                ' "id")) in subgraph "blocked" but that subgraph is missing'
                ' some of the supergraph implementation types of "User".'
                ' Subgraph "blocked" should define type "RegisteredUser" (and'
                ' have it implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [extra] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "extra" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "extra"'
                ' should define type "BlockedUser" (and have it implement'
                ' "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "email")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "BlockedUser" and "RegisteredUser" (and'
                ' have them implement "User").'
            ),
        ],
    )


def test_v2_9_interface_key_missing_implementation_type_interfaceobject_interface_is_vali() raises:
    # v2.9 > INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE: @interfaceObject + interface is valid
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ninterface Node'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n  a:'
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id:'
                    " ID!\n}\n\ntype Query {\n  b: String\n}"
                ),
            ),
        ],
        [],
    )


def test_three_implementation_types() raises:
    # extra: three missing types use a comma and then "and"
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface User @key(fields: "id") {\n  id:'
                    " ID!\n}"
                ),
            ),
            sg(
                "d",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype D implements User @key(fields: "id")'
                    " {\n  id: ID!\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "e",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype E implements User @key(fields: "id")'
                    " {\n  id: ID!\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "f",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype F implements User @key(fields: "id")'
                    " {\n  id: ID!\n}\n\nextend interface User @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [d] Interface type"
                ' "User" has a resolvable key (@key(fields: "id")) in subgraph'
                ' "d" but that subgraph is missing some of the supergraph'
                ' implementation types of "User". Subgraph "d" should define'
                ' types "E" and "F" (and have them implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [e] Interface type"
                ' "User" has a resolvable key (@key(fields: "id")) in subgraph'
                ' "e" but that subgraph is missing some of the supergraph'
                ' implementation types of "User". Subgraph "e" should define'
                ' types "D" and "F" (and have them implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [f] Interface type"
                ' "User" has a resolvable key (@key(fields: "id")) in subgraph'
                ' "f" but that subgraph is missing some of the supergraph'
                ' implementation types of "User". Subgraph "f" should define'
                ' types "D" and "E" (and have them implement "User").'
            ),
            (
                "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] [users] Interface"
                ' type "User" has a resolvable key (@key(fields: "id")) in'
                ' subgraph "users" but that subgraph is missing some of the'
                ' supergraph implementation types of "User". Subgraph "users"'
                ' should define types "D", "E" and "F" (and have them implement'
                ' "User").'
            ),
        ],
    )


def _key_message(graph: String, missing: String) -> String:
    return (
        "[INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE] ["
        + graph
        + '] Interface type "Node" has a resolvable key (@key(fields: "id"))'
        + ' in subgraph "'
        + graph
        + '" but that subgraph is missing some of the supergraph'
        + ' implementation types of "Node". Subgraph "'
        + graph
        + '" should define type '
        + missing
        + ' (and have it implement "Node").'
    )


def test_unkeyed_and_absent_interface() raises:
    # Subgraph "b" has the interface without a key, and "d" has no
    # interface. Subgraph "a" defines every implementer, so Hive names
    # the empty type "".
    var head = String(
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3", import: ["@key"])\n\n'
    )
    check(
        [
            sg(
                "a",
                head
                + "type Query {\n  n: Node\n}\n\ninterface Node @key(fields:"
                ' "id")'
                + " {\n  id: ID!\n}\n\ntype User implements Node @key(fields:"
                ' "id")'
                + " {\n  id: ID!\n}",
            ),
            sg("b", head + "interface Node {\n  id: ID!\n}"),
            sg(
                "c",
                head + 'interface Node @key(fields: "id") {\n  id: ID!\n}',
            ),
            sg("d", head + 'type Other @key(fields: "id") {\n  id: ID!\n}'),
        ],
        [_key_message("a", '""'), _key_message("c", '"User"')],
    )


def test_keyed_interface_without_implementers() raises:
    # No subgraph implements the interface.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  n: Node\n}\n\ninterface'
                    ' Node @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [_key_message("a", '""')],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
