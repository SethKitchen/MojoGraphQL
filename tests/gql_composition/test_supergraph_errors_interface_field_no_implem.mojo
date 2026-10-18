# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/INTERFACE_FIELD_NO_IMPLEM.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors include Hive `INTERFACE_FIELD_NO_IMPLEM` from
`composeServices` on the same subgraphs. A type-kind mismatch comes
from the earlier kind check and stops this rule.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_interface_field_no_implem_entity() raises:
    # v2.0 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_0_interface_field_no_implem_data() raises:
    # v2.0 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_0_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.0 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_1_interface_field_no_implem_entity() raises:
    # v2.1 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_1_interface_field_no_implem_data() raises:
    # v2.1 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_1_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.1 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_2_interface_field_no_implem_entity() raises:
    # v2.2 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_2_interface_field_no_implem_data() raises:
    # v2.2 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_2_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.2 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_3_interface_field_no_implem_entity() raises:
    # v2.3 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_3_interface_field_no_implem_data() raises:
    # v2.3 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_3_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.3 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_4_interface_field_no_implem_entity() raises:
    # v2.4 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_4_interface_field_no_implem_data() raises:
    # v2.4 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_4_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.4 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_5_interface_field_no_implem_entity() raises:
    # v2.5 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_5_interface_field_no_implem_data() raises:
    # v2.5 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_5_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.5 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_6_interface_field_no_implem_entity() raises:
    # v2.6 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_6_interface_field_no_implem_data() raises:
    # v2.6 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_6_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.6 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_7_interface_field_no_implem_entity() raises:
    # v2.7 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_7_interface_field_no_implem_data() raises:
    # v2.7 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_7_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.7 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_8_interface_field_no_implem_entity() raises:
    # v2.8 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_8_interface_field_no_implem_data() raises:
    # v2.8 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_8_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.8 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_v2_9_interface_field_no_implem_entity() raises:
    # v2.9 > INTERFACE_FIELD_NO_IMPLEM (entity)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' RegisteredUser implements User @key(fields: "id") {\n '
                    " id: ID!\n  name: String!\n  email: String\n}\n\ninterface"
                    " User {\n  id: ID!\n  name: String!\n  email: String\n}"
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ninterface User {\n  id: ID!\n  name:'
                    " String!\n}\n\ntype Author implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def test_v2_9_interface_field_no_implem_data() raises:
    # v2.9 > INTERFACE_FIELD_NO_IMPLEM (data)
    check(
        [
            sg(
                "foo",
                (
                    "type Query {\n  foo: Foo\n}\n\ntype Foo implements Person"
                    " {\n  name: String\n  age: Int\n}\n\ninterface Person {\n "
                    " name: String\n  age: Int\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "type Query {\n  bar: Bar\n}\n\ntype Bar implements Person"
                    " {\n  name: String\n}\n\ninterface Person {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Person.age" is'
                ' declared in subgraph "foo" but type "Bar", which implements'
                ' "Person" in subgraph "bar" does not have field "age".'
            ),
        ],
    )


def test_v2_9_ignoring_interface_field_no_implem_when_type_kind_mismatch_detected() raises:
    # v2.9 > Ignoring INTERFACE_FIELD_NO_IMPLEM when TYPE_KIND_MISMATCH detected
    check(
        [
            sg(
                "cars",
                (
                    "type Query {\n  foo(id: ID!): String\n}\n\ninterface"
                    " Vehicle {\n  id: ID!\n}\n\ntype Car implements Vehicle"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "vehicles",
                "type Vehicle {\n  id: ID!\n}",
            ),
        ],
        [
            (
                '[TYPE_KIND_MISMATCH] Type "Vehicle" has mismatched kind: it is'
                ' defined as Interface Type in subgraph "cars" but Object Type'
                ' in subgraph "vehicles"'
            ),
        ],
    )


def test_field_declared_in_two_subgraphs() raises:
    # extra: the plural "subgraphs" phrase
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  a: A\n}\n\ninterface Node'
                    " {\n  id: ID!\n  extra: String\n}\n\ntype A implements"
                    ' Node @key(fields: "id") {\n  id: ID!\n  extra: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninterface Node {\n  id: ID!\n  extra:'
                    ' String\n}\n\ntype B implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  extra: String\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninterface Node {\n  id: ID!\n}\n\ntype C'
                    ' implements Node @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "Node.extra" is'
                ' declared in subgraphs "a", "b" but type "C", which implements'
                ' "Node" in subgraph "c" does not have field "extra".'
            ),
        ],
    )


def test_interface_object_field_is_not_required() raises:
    # extra: a non-external field of @interfaceObject is not required
    check(
        [
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  media:'
                    " Media\n}\n\ntype Media @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  reviews: [String!]!\n}'
                ),
            ),
            sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    ' ID!\n}\n\ntype Book implements Media @key(fields: "id")'
                    " {\n  id: ID!\n  title: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_subgraph_without_the_interface() raises:
    # A third subgraph that does not define the interface is not listed.
    var head = String(
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.0", import: ["@key"])\n\n'
    )
    check(
        [
            sg(
                "users",
                head
                + "type Query {\n  users: [User]\n}\n\ntype RegisteredUser"
                ' implements User @key(fields: "id") {\n  id: ID!\n  name:'
                " String!\n  email: String\n}\n\ninterface User {\n  id: ID!\n"
                "  name: String!\n  email: String\n}",
            ),
            sg(
                "feed",
                head
                + "interface User {\n  id: ID!\n  name: String!\n}\n\ntype"
                ' Author implements User @key(fields: "id") {\n  id: ID!\n '
                " name: String!\n}",
            ),
            sg("other", head + 'type Other @key(fields: "id") {\n  id: ID!\n}'),
        ],
        [
            (
                '[INTERFACE_FIELD_NO_IMPLEM] Interface field "User.email" is'
                ' declared in subgraph "users" but type "Author", which'
                ' implements "User" in subgraph "feed" does not have field'
                ' "email".'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
