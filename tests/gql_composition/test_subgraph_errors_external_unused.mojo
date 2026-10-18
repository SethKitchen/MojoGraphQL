# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/EXTERNAL_UNUSED.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_external_unused_on_field() raises:
    # v2.0 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_0_external_unused_on_type() raises:
    # v2.0 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_0_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.0 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_fed_v1_no_external_unused() raises:
    # v2.0 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.0 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_0_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.0 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_1_external_unused_on_field() raises:
    # v2.1 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_1_external_unused_on_type() raises:
    # v2.1 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_1_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.1 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_fed_v1_no_external_unused() raises:
    # v2.1 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.1 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_1_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.1 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_2_external_unused_on_field() raises:
    # v2.2 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_2_external_unused_on_type() raises:
    # v2.2 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_2_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.2 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_fed_v1_no_external_unused() raises:
    # v2.2 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.2 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_2_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.2 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_3_external_unused_on_field() raises:
    # v2.3 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_3_external_unused_on_type() raises:
    # v2.3 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_3_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.3 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_fed_v1_no_external_unused() raises:
    # v2.3 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.3 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_3_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.3 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_4_external_unused_on_field() raises:
    # v2.4 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_4_external_unused_on_type() raises:
    # v2.4 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_4_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.4 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_fed_v1_no_external_unused() raises:
    # v2.4 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.4 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_4_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.4 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_5_external_unused_on_field() raises:
    # v2.5 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_5_external_unused_on_type() raises:
    # v2.5 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_5_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.5 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_fed_v1_no_external_unused() raises:
    # v2.5 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.5 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_5_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.5 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_6_external_unused_on_field() raises:
    # v2.6 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_6_external_unused_on_type() raises:
    # v2.6 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_6_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.6 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_fed_v1_no_external_unused() raises:
    # v2.6 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.6 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_6_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.6 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_7_external_unused_on_field() raises:
    # v2.7 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_7_external_unused_on_type() raises:
    # v2.7 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_7_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.7 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_fed_v1_no_external_unused() raises:
    # v2.7 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.7 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_7_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.7 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_external_unused_on_field() raises:
    # v2.8 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_8_external_unused_on_type() raises:
    # v2.8 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_8_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.8 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_fed_v1_no_external_unused() raises:
    # v2.8 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.8 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.8 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_external_unused_on_field() raises:
    # v2.9 > EXTERNAL_UNUSED on field
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String! @external\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_9_external_unused_on_type() raises:
    # v2.9 > EXTERNAL_UNUSED on type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") @external {\n '
                    " id: ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_UNUSED] [users] Field "User.name" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_9_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # v2.9 > EXTERNAL_UNUSED on requires with union selection set does not raise an error
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_fed_v1_no_external_unused() raises:
    # v2.9 > Fed v1: No EXTERNAL_UNUSED
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_fed_v1_no_external_unused_when_external_is_used_on_a_type() raises:
    # v2.9 > Fed v1: No EXTERNAL_UNUSED when @external is used on a type
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") @external {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_fed_v1_no_external_unused_but_external_missing_on_base_on_key_field() raises:
    # v2.9 > Fed v1: No EXTERNAL_UNUSED but EXTERNAL_MISSING_ON_BASE on key field
    check(
        [
            sg(
                "users",
                (
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID! @external\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  nick: String!'
                    " @external\n  age: Int!\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "a",
                (
                    'type Admin @key(fields: "id") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  admin: Admin\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Query {\n  users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    'extend type User @key(fields: "nickname") {\n  nickname:'
                    " String! @external\n  age: Int!\n}\n\ntype Query {\n "
                    " user: User\n}"
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
                    "type Query {\n  users: [User]\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String! @external\n}'
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
