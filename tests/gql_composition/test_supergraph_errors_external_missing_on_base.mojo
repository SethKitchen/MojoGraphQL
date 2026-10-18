# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/EXTERNAL_MISSING_ON_BASE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `EXTERNAL_MISSING_ON_BASE` from
`composeServices` on the same subgraphs. A key field on an extension,
and a Federation 1 `@external` field that nothing uses, expect an
empty list.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_external_missing_on_base() raises:
    # v2.0 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_fed_v1_external_missing_on_base() raises:
    # v2.0 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.0 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_external_missing_on_base() raises:
    # v2.1 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_fed_v1_external_missing_on_base() raises:
    # v2.1 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.1 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_external_missing_on_base() raises:
    # v2.2 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_fed_v1_external_missing_on_base() raises:
    # v2.2 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.2 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_external_missing_on_base() raises:
    # v2.3 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_fed_v1_external_missing_on_base() raises:
    # v2.3 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.3 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_external_in_types_defined_by_interfaceobject() raises:
    # v2.3 > @external in types, defined by @interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  animal:'
                    " Animal\n}\n\ntype Animal @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  age: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external"])\n\ninterface Mammal {\n  id: ID!\n'
                    "  age: Int\n}\n\ninterface Animal implements Mammal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int\n}\n\ntype Dog implements Mammal & Animal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_external_missing_on_base() raises:
    # v2.4 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_fed_v1_external_missing_on_base() raises:
    # v2.4 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.4 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_external_in_types_defined_by_interfaceobject() raises:
    # v2.4 > @external in types, defined by @interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  animal:'
                    " Animal\n}\n\ntype Animal @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  age: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@external"])\n\ninterface Mammal {\n  id: ID!\n'
                    "  age: Int\n}\n\ninterface Animal implements Mammal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int\n}\n\ntype Dog implements Mammal & Animal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_external_missing_on_base() raises:
    # v2.5 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_fed_v1_external_missing_on_base() raises:
    # v2.5 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.5 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_external_in_types_defined_by_interfaceobject() raises:
    # v2.5 > @external in types, defined by @interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  animal:'
                    " Animal\n}\n\ntype Animal @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  age: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@external"])\n\ninterface Mammal {\n  id: ID!\n'
                    "  age: Int\n}\n\ninterface Animal implements Mammal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int\n}\n\ntype Dog implements Mammal & Animal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_external_missing_on_base() raises:
    # v2.6 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_fed_v1_external_missing_on_base() raises:
    # v2.6 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.6 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_external_in_types_defined_by_interfaceobject() raises:
    # v2.6 > @external in types, defined by @interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  animal:'
                    " Animal\n}\n\ntype Animal @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  age: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@external"])\n\ninterface Mammal {\n  id: ID!\n'
                    "  age: Int\n}\n\ninterface Animal implements Mammal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int\n}\n\ntype Dog implements Mammal & Animal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_external_missing_on_base() raises:
    # v2.7 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_fed_v1_external_missing_on_base() raises:
    # v2.7 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.7 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_external_in_types_defined_by_interfaceobject() raises:
    # v2.7 > @external in types, defined by @interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  animal:'
                    " Animal\n}\n\ntype Animal @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  age: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@external"])\n\ninterface Mammal {\n  id: ID!\n'
                    "  age: Int\n}\n\ninterface Animal implements Mammal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int\n}\n\ntype Dog implements Mammal & Animal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_external_missing_on_base() raises:
    # v2.8 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_fed_v1_external_missing_on_base() raises:
    # v2.8 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.8 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_external_in_types_defined_by_interfaceobject() raises:
    # v2.8 > @external in types, defined by @interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  animal:'
                    " Animal\n}\n\ntype Animal @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  age: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@external"])\n\ninterface Mammal {\n  id: ID!\n'
                    "  age: Int\n}\n\ninterface Animal implements Mammal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int\n}\n\ntype Dog implements Mammal & Animal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_external_missing_on_base() raises:
    # v2.9 > EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  profile: Profile @external\n  friends: [User]"
                    ' @requires(fields: "profile { name }")\n}\n\ntype Profile'
                    " {\n  name: String\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires", "@extends"])\n\ntype'
                    " Query {\n  users: [User]\n}\n\ntype User @extends"
                    ' @key(fields: "userId") {\n  userId: String @external\n '
                    " name: String @external\n  fullName: String"
                    ' @requires(fields: "name")\n}'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "users").'
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@extends"])\n\ntype Query {\n '
                    ' users: [User]\n}\n\ntype User @extends @key(fields: "id")'
                    " {\n  id: ID! @external\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_fed_v1_external_missing_on_base() raises:
    # v2.9 > Fed v1: EXTERNAL_MISSING_ON_BASE
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n  comments:"
                    ' [String] @requires(fields: "internalId")\n}\n\ntype Query'
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.internalId" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    'type User @extends @key(fields: "id") {\n  internalId:'
                    " String @external\n  id: ID! @external\n}\n\ntype Query"
                    " {\n  word: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @extends @key(fields: "id") {\n  tags:'
                    " [String!]!\n  id: ID! @external\n}\n\ntype Query {\n "
                    " sentence: [String]\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_field_can_be_external_only_if_it_is_a_key_and_the_object_type_uses_extend() raises:
    # v2.9 > Field can be '@external'-only if it is a '@key' and the object type uses 'extend'
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    ' SharedType @key(fields: "id") {\n  id: ID! @external\n '
                    " dependency: String! @external\n}\n\nextend type"
                    ' SharedType @key(fields: "secondId") {\n  secondId: ID!'
                    " @external\n  someFieldThatRequiresDependency: String"
                    ' @requires(fields: "dependency")\n}\n\ntype Query {\n  a:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype SharedType @key(fields: "secondId") {\n'
                    "  type: String!\n  secondId: ID!\n  dependency:"
                    " String!\n}\n\ntype Query {\n  c: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_external_in_types_defined_by_interfaceobject() raises:
    # v2.9 > @external in types, defined by @interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  animal:'
                    " Animal\n}\n\ntype Animal @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  age: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external"])\n\ninterface Mammal {\n  id: ID!\n'
                    "  age: Int\n}\n\ninterface Animal implements Mammal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int\n}\n\ntype Dog implements Mammal & Animal"
                    ' @key(fields: "id") {\n  id: ID!\n  origin: String\n  age:'
                    " Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_hive_case_em1c_type_external_two() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { u: User'
                    ' @provides(fields: "name") }\ntype User @key(fields:'
                    ' "id") @external { id: ID! name: String }'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { v: User'
                    ' @provides(fields: "name") }\ntype User @key(fields:'
                    ' "id") @external { id: ID! name: String }'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraphs "a" and "b").'
            ),
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.id" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraphs "a" and "b").'
            ),
        ],
    )


def test_hive_case_em2_two() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { users: [User]'
                    ' }\ntype User @key(fields: "id") { id: ID profile:'
                    " Profile @external friends: [User] @requires(fields:"
                    ' "profile { name }") }\ntype Profile { name: String }'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID profile: Profile @external others:'
                    ' [User] @requires(fields: "profile { name }") }\ntype'
                    " Profile { name: String }"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is'
                " marked @external on all the subgraphs in which it is"
                ' listed (subgraphs "a" and "b").'
            ),
            (
                "[INVALID_FIELD_SHARING] Non-shareable field"
                ' "Profile.name" is resolved from multiple subgraphs: it'
                ' is resolved from subgraphs "a" and "b" and defined as'
                " non-shareable in all of them"
            ),
        ],
    )


def test_hive_case_em2_three() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { users: [User]'
                    ' }\ntype User @key(fields: "id") { id: ID profile:'
                    " Profile @external friends: [User] @requires(fields:"
                    ' "profile { name }") }\ntype Profile { name: String }'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID profile: Profile @external others:'
                    ' [User] @requires(fields: "profile { name }") }\ntype'
                    " Profile { name: String }"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID profile: Profile @external more: [User]'
                    ' @requires(fields: "profile { name }") }\ntype Profile {'
                    " name: String }"
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.profile" is'
                " marked @external on all the subgraphs in which it is"
                ' listed (subgraphs "a", "b", and "c").'
            ),
            (
                "[INVALID_FIELD_SHARING] Non-shareable field"
                ' "Profile.name" is resolved from multiple subgraphs: it'
                ' is resolved from subgraphs "a", "b" and "c" and defined'
                " as non-shareable in all of them"
            ),
        ],
    )


def test_hive_case_em3_iobj_missing_field() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { n: Node'
                    ' }\ninterface Node @key(fields: "id") { id: ID! }\ntype'
                    ' User implements Node @key(fields: "id") { id: ID! name:'
                    " String @external computed: String @requires(fields:"
                    ' "name") }'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Node @interfaceObject'
                    ' @key(fields: "id") { id: ID! other: String }'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )


def test_hive_case_em3_iobj_external_field() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { n: Node'
                    ' }\ninterface Node @key(fields: "id") { id: ID! name:'
                    ' String }\ntype User implements Node @key(fields: "id") {'
                    " id: ID! name: String @external computed: String"
                    ' @requires(fields: "name") }'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Node @interfaceObject'
                    ' @key(fields: "id") { id: ID! name: String @external'
                    ' computed2: String @requires(fields: "name") }'
                ),
            ),
        ],
        [
            (
                '[EXTERNAL_MISSING_ON_BASE] Field "User.name" is marked'
                " @external on all the subgraphs in which it is listed"
                ' (subgraph "a").'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
