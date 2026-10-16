# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/INVALID_FIELD_SHARING.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_invalid_field_sharing_set_of_tests() raises:
    # v2.0 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_invalid_field_sharing_fed_v1() raises:
    # v2.0 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.0 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_invalid_field_sharing_subscription_fields() raises:
    # v2.0 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_invalid_field_sharing_nested_key_fields() raises:
    # v2.0 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.0 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_invalid_field_sharing_set_of_tests() raises:
    # v2.1 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_invalid_field_sharing_fed_v1() raises:
    # v2.1 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.1 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_invalid_field_sharing_subscription_fields() raises:
    # v2.1 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_invalid_field_sharing_nested_key_fields() raises:
    # v2.1 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.1 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_invalid_field_sharing_set_of_tests() raises:
    # v2.2 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_invalid_field_sharing_fed_v1() raises:
    # v2.2 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.2 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_invalid_field_sharing_subscription_fields() raises:
    # v2.2 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_invalid_field_sharing_nested_key_fields() raises:
    # v2.2 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.2 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_invalid_field_sharing_set_of_tests() raises:
    # v2.3 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_invalid_field_sharing_fed_v1() raises:
    # v2.3 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.3 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_invalid_field_sharing_subscription_fields() raises:
    # v2.3 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_invalid_field_sharing_nested_key_fields() raises:
    # v2.3 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.3 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_invalid_field_sharing_set_of_tests() raises:
    # v2.4 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_invalid_field_sharing_fed_v1() raises:
    # v2.4 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.4 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_invalid_field_sharing_subscription_fields() raises:
    # v2.4 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_invalid_field_sharing_nested_key_fields() raises:
    # v2.4 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.4 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_invalid_field_sharing_set_of_tests() raises:
    # v2.5 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_invalid_field_sharing_fed_v1() raises:
    # v2.5 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.5 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_invalid_field_sharing_subscription_fields() raises:
    # v2.5 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_invalid_field_sharing_nested_key_fields() raises:
    # v2.5 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.5 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_invalid_field_sharing_set_of_tests() raises:
    # v2.6 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_invalid_field_sharing_fed_v1() raises:
    # v2.6 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.6 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_invalid_field_sharing_subscription_fields() raises:
    # v2.6 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_invalid_field_sharing_nested_key_fields() raises:
    # v2.6 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.6 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_invalid_field_sharing_set_of_tests() raises:
    # v2.7 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_invalid_field_sharing_fed_v1() raises:
    # v2.7 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.7 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_invalid_field_sharing_subscription_fields() raises:
    # v2.7 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_invalid_field_sharing_nested_key_fields() raises:
    # v2.7 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.7 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_invalid_field_sharing_set_of_tests() raises:
    # v2.8 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_invalid_field_sharing_fed_v1() raises:
    # v2.8 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.8 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_invalid_field_sharing_subscription_fields() raises:
    # v2.8 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_invalid_field_sharing_nested_key_fields() raises:
    # v2.8 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.8 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_invalid_field_sharing_set_of_tests() raises:
    # v2.9 > INVALID_FIELD_SHARING > set of tests
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID\n  profile: Profile\n}\n\ntype Profile @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  user: User\n}\n\ntype User {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  comments: [String]\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\nextend type Query {\n  foo: Foo\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "feed",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@override\"])\n\nextend type Query {\n  foo: Foo @override(from: \"noop\")\n}\n\ntype Foo @shareable @key(fields: \"id\") {\n  id: ID!\n  name: String\n}",
            ),
            sg(
                "noop",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  noop: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String! @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\nextend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_invalid_field_sharing_fed_v1() raises:
    # v2.9 > INVALID_FIELD_SHARING > fed v1
    check(
        [
            sg(
                "foo",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note {\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  foo: String!\n}",
            ),
            sg(
                "bar",
                "extend type Note @key(fields: \"id\") {\n  id: ID!\n  url: String!\n}\n\ntype Note {\n  name: String!\n}\n\ntype Query {\n  bar: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_invalid_field_sharing_subscription_fields_fed_v1() raises:
    # v2.9 > INVALID_FIELD_SHARING > subscription fields (fed v1)
    check(
        [
            sg(
                "foo",
                "type Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
            sg(
                "bar",
                "type Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_invalid_field_sharing_subscription_fields() raises:
    # v2.9 > INVALID_FIELD_SHARING > subscription fields
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Query {\n  foo: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Query {\n  bar: String\n}\n\ntype Subscription {\n  event: String @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_invalid_field_sharing_nested_key_fields() raises:
    # v2.9 > INVALID_FIELD_SHARING > nested key fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype A @key(fields: \"id\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype Query {\n  b: B\n}\n\ntype B @key(fields: \"id\") {\n  id: ID!\n  a: [A!]!\n}\n\ntype A @key(fields: \"compositeId { one two }\", resolvable: false) @key(fields: \"id compositeId { two three }\", resolvable: true) @key(fields: \"pId\", resolvable: false) @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n  name: String! @external\n  nameInB: String! @requires(fields: \"name\")\n}\n\ntype CompositeID {\n  one: ID!\n  two: ID!\n  three: ID!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_non_shareable_field_in_interfaceobject_and_interface_implementation() raises:
    # v2.9 > non-shareable field in @interfaceObject and interface implementation
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
