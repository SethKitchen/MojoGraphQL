# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/composition.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_enum_value_as_string_as_default_value() raises:
    # enum value as string as default value
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users(type: UserType! = \"Regular\"): [User!]!\n}\n\nenum UserType {\n  Regular\n  Admin\n}",
            ),
        ],
        [
        ],
    )


def test_duplicated_query_fields() raises:
    # duplicated Query fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  userById(id: ID!): User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  userById(id: ID!): User\n}",
            ),
        ],
        [
        ],
    )


def test_join_field_usedoverridden_true_when_field_is_overridden_but_defined_in_an_interf() raises:
    # @join__field(usedOverridden: true) when field is overridden but defined in an interface
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninterface Post {\n  id: ID!\n  createdAt: String!\n}\n\ntype ImagePost implements Post @key(fields: \"id\") {\n  id: ID!\n  createdAt: String!\n}\n\ntype Query {\n  feed: [Post]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ninterface Post {\n  id: ID!\n  createdAt: String!\n}\n\ntype TextPost implements Post @key(fields: \"id\") {\n  id: ID!\n  createdAt: String!\n  body: String!\n}\n\ninterface AnotherPost {\n  id: ID!\n  createdAt: String!\n}\n\ntype ImagePost implements AnotherPost @key(fields: \"id\") {\n  id: ID!\n  createdAt: String! @override(from: \"a\")\n}\n\ntype Query {\n  anotherFeed: [AnotherPost]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype ImagePost @key(fields: \"id\") {\n  id: ID!\n  createdAt: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ninterface Post {\n  id: ID!\n  createdAt: String!\n}\n\ntype TextPost implements Post @key(fields: \"id\") {\n  id: ID!\n  createdAt: String!\n  body: String!\n}\n\ninterface AnotherPost {\n  id: ID!\n  createdAt: String!\n}\n\ntype ImagePost implements AnotherPost @key(fields: \"id\") {\n  id: ID!\n  createdAt: String! @override(from: \"a\")\n}\n\ntype Query {\n  anotherFeed: [AnotherPost]\n}",
            ),
        ],
        [
        ],
    )


def test_join_field_external_true_when_field_is_overridden() raises:
    # @join__field(external: true) when field is overridden
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  cName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userC: User\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  cName: String!\n}\n\ntype Query {\n  userC: User\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_override_a_field_with_requires() raises:
    # @override a field with @requires
    check(
        [
            sg(
                "core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n}",
            ),
            sg(
                "original",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @external\n  paymentReceipt: String! @shareable @requires(fields: \"creditCardNumber\")\n}",
            ),
            sg(
                "new",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  creditCardNumber: String! @shareable\n  paymentReceipt: String! @shareable @override(from: \"original\")\n}",
            ),
        ],
        [
        ],
    )


def test_print_join_field_on_shareable_field_defined_twice_once_with_non_effective_overri() raises:
    # print @join__field on shareable field defined twice (once with non-effective override)
    check(
        [
            sg(
                "a",
                "type Mutation {\n  a: String!\n  b: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@override\"])\n\ntype Mutation {\n  a: String! @shareable @override(from: \"non-existing\")\n  b: String! @shareable @override(from: \"non-existing\")\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Mutation {\n  c: String!\n}\n\ntype Query {\n  c: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_two_exact_same_types() raises:
    # v2.0 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.0 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.0 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.0 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.0 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.0 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.0 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.0 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.0 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.0 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_object_types_with_different_fields() raises:
    # v2.0 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.0 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.0 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_interface_types_with_different_fields() raises:
    # v2.0 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.0 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_union_types_with_different_members() raises:
    # v2.0 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_input_types_and_field_arguments() raises:
    # v2.0 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_default_values_print() raises:
    # v2.0 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.0 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.0 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.0 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.0 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.0 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.0 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.0 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.0 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.0 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.0 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.0 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.0 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.0 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_requires_on_a_union_with_typename_fails() raises:
    # v2.0 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.0 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.0 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.0 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.0 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.0 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.0 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.0 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.0 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.0 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.0 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.0 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.0 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_import_type() raises:
    # v2.0 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.0 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_renaming_directives() raises:
    # v2.0 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_namespaced_directives() raises:
    # v2.0 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_repeatable_key() raises:
    # v2.0 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_interfaceobject() raises:
    # v2.0 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@interfaceObject\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@interfaceObject\".",
        ],
    )


def test_v2_0_extends() raises:
    # v2.0 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_override() raises:
    # v2.0 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.0 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.0 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_provides_itself_circular_reference() raises:
    # v2.0 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_external_provides() raises:
    # v2.0 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_external_requires() raises:
    # v2.0 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.0 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_external_tag() raises:
    # v2.0 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_tag() raises:
    # v2.0 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_tag_on_directive() raises:
    # v2.0 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.0 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.0 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.0 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.0 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.0 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.0 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.0 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.0 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.0 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.0 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.0 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_join_implements_on_interface_type() raises:
    # v2.0 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.0 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_scalars() raises:
    # v2.0 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_object_types() raises:
    # v2.0 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_fields_with_override_entity_types() raises:
    # v2.0 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.0 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_object_type_definition_with_extends() raises:
    # v2.0 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_object_types_with_arguments() raises:
    # v2.0 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_input_object_types() raises:
    # v2.0 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.0 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.0 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.0 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_union_types() raises:
    # v2.0 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_descriptions_on_interface_types() raises:
    # v2.0 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_deprecated_on_object_types() raises:
    # v2.0 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_deprecated_on_input_object_types() raises:
    # v2.0 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.0 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.0 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.0 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.0 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_federation_directives_and_types_link_and_join_spec() raises:
    # v2.0 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.0 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_two_exact_same_types() raises:
    # v2.1 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.1 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.1 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.1 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.1 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.1 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.1 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.1 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.1 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.1 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_object_types_with_different_fields() raises:
    # v2.1 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.1 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.1 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_interface_types_with_different_fields() raises:
    # v2.1 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.1 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_union_types_with_different_members() raises:
    # v2.1 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_input_types_and_field_arguments() raises:
    # v2.1 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_default_values_print() raises:
    # v2.1 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.1 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_1_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.1 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.1 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.1 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.1 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.1 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.1 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.1 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.1 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.1 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.1 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.1 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.1 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.1 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.1 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.1 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.1 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_requires_on_a_union_with_typename_fails() raises:
    # v2.1 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.1 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.1 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.1 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.1 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.1 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.1 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.1 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.1 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.1 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.1 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.1 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.1 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_import_type() raises:
    # v2.1 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.1 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_renaming_directives() raises:
    # v2.1 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_namespaced_directives() raises:
    # v2.1 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_repeatable_key() raises:
    # v2.1 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_interfaceobject() raises:
    # v2.1 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@interfaceObject\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@interfaceObject\".",
        ],
    )


def test_v2_1_extends() raises:
    # v2.1 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_override() raises:
    # v2.1 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.1 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.1 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_provides_itself_circular_reference() raises:
    # v2.1 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_external_provides() raises:
    # v2.1 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_external_requires() raises:
    # v2.1 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.1 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_external_tag() raises:
    # v2.1 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_tag() raises:
    # v2.1 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_tag_on_directive() raises:
    # v2.1 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.1 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.1 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.1 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.1 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.1 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.1 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.1 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.1 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.1 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.1 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.1 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_join_implements_on_interface_type() raises:
    # v2.1 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.1 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_scalars() raises:
    # v2.1 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_object_types() raises:
    # v2.1 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_fields_with_override_entity_types() raises:
    # v2.1 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.1 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_object_type_definition_with_extends() raises:
    # v2.1 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_object_types_with_arguments() raises:
    # v2.1 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_input_object_types() raises:
    # v2.1 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.1 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.1 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.1 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_union_types() raises:
    # v2.1 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_descriptions_on_interface_types() raises:
    # v2.1 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_deprecated_on_object_types() raises:
    # v2.1 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_deprecated_on_input_object_types() raises:
    # v2.1 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.1 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.1 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.1 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.1 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_federation_directives_and_types_link_and_join_spec() raises:
    # v2.1 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.1 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_two_exact_same_types() raises:
    # v2.2 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.2 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.2 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.2 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.2 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.2 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.2 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.2 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.2 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.2 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_object_types_with_different_fields() raises:
    # v2.2 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.2 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.2 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_interface_types_with_different_fields() raises:
    # v2.2 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.2 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_union_types_with_different_members() raises:
    # v2.2 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_input_types_and_field_arguments() raises:
    # v2.2 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_default_values_print() raises:
    # v2.2 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.2 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_2_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.2 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.2 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.2 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.2 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.2 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.2 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.2 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.2 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.2 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.2 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.2 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.2 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.2 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.2 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.2 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.2 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_requires_on_a_union_with_typename_fails() raises:
    # v2.2 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.2 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.2 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.2 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.2 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.2 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.2 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.2 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.2 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.2 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.2 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.2 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.2 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_import_type() raises:
    # v2.2 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.2 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_renaming_directives() raises:
    # v2.2 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_namespaced_directives() raises:
    # v2.2 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_repeatable_key() raises:
    # v2.2 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_interfaceobject() raises:
    # v2.2 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@interfaceObject\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@interfaceObject\".",
        ],
    )


def test_v2_2_extends() raises:
    # v2.2 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_override() raises:
    # v2.2 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.2 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.2 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_provides_itself_circular_reference() raises:
    # v2.2 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_external_provides() raises:
    # v2.2 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_external_requires() raises:
    # v2.2 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.2 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_external_tag() raises:
    # v2.2 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_tag() raises:
    # v2.2 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_tag_on_directive() raises:
    # v2.2 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.2 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.2 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.2 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.2 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.2 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.2 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.2 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.2 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.2 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.2 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.2 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_join_implements_on_interface_type() raises:
    # v2.2 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.2 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_scalars() raises:
    # v2.2 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_object_types() raises:
    # v2.2 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_fields_with_override_entity_types() raises:
    # v2.2 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.2 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_object_type_definition_with_extends() raises:
    # v2.2 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_object_types_with_arguments() raises:
    # v2.2 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_input_object_types() raises:
    # v2.2 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.2 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.2 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.2 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_union_types() raises:
    # v2.2 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_descriptions_on_interface_types() raises:
    # v2.2 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_deprecated_on_object_types() raises:
    # v2.2 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_deprecated_on_input_object_types() raises:
    # v2.2 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.2 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.2 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.2 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.2 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_federation_directives_and_types_link_and_join_spec() raises:
    # v2.2 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.2 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_two_exact_same_types() raises:
    # v2.3 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.3 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.3 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.3 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.3 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.3 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.3 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.3 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.3 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.3 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_object_types_with_different_fields() raises:
    # v2.3 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.3 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.3 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_interface_types_with_different_fields() raises:
    # v2.3 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.3 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_union_types_with_different_members() raises:
    # v2.3 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_input_types_and_field_arguments() raises:
    # v2.3 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_default_values_print() raises:
    # v2.3 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.3 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_3_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.3 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.3 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.3 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.3 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.3 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.3 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.3 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.3 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.3 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.3 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.3 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.3 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.3 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.3 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.3 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.3 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_requires_on_a_union_with_typename_fails() raises:
    # v2.3 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.3 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.3 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.3 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.3 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.3 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.3 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.3 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.3 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.3 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.3 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.3 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.3 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_import_type() raises:
    # v2.3 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.3 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_renaming_directives() raises:
    # v2.3 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_namespaced_directives() raises:
    # v2.3 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_repeatable_key() raises:
    # v2.3 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_interfaceobject() raises:
    # v2.3 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_extends() raises:
    # v2.3 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_override() raises:
    # v2.3 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.3 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.3 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_provides_itself_circular_reference() raises:
    # v2.3 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_external_provides() raises:
    # v2.3 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_external_requires() raises:
    # v2.3 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.3 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_external_tag() raises:
    # v2.3 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_tag() raises:
    # v2.3 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_tag_on_directive() raises:
    # v2.3 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.3 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.3 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.3 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.3 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.3 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.3 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.3 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.3 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.3 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.3 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.3 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_join_implements_on_interface_type() raises:
    # v2.3 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.3 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_scalars() raises:
    # v2.3 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_object_types() raises:
    # v2.3 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_fields_with_override_entity_types() raises:
    # v2.3 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.3 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_object_type_definition_with_extends() raises:
    # v2.3 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_object_types_with_arguments() raises:
    # v2.3 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_input_object_types() raises:
    # v2.3 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.3 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.3 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.3 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_union_types() raises:
    # v2.3 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_descriptions_on_interface_types() raises:
    # v2.3 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_deprecated_on_object_types() raises:
    # v2.3 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_deprecated_on_input_object_types() raises:
    # v2.3 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.3 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.3 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.3 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.3 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_federation_directives_and_types_link_and_join_spec() raises:
    # v2.3 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.3 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_two_exact_same_types() raises:
    # v2.4 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.4 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.4 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.4 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.4 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.4 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.4 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.4 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.4 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.4 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_object_types_with_different_fields() raises:
    # v2.4 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.4 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.4 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_interface_types_with_different_fields() raises:
    # v2.4 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.4 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_union_types_with_different_members() raises:
    # v2.4 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_input_types_and_field_arguments() raises:
    # v2.4 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_default_values_print() raises:
    # v2.4 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.4 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_4_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.4 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.4 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.4 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.4 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.4 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.4 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.4 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.4 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.4 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.4 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.4 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.4 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.4 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.4 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.4 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.4 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_requires_on_a_union_with_typename_fails() raises:
    # v2.4 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.4 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.4 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.4 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.4 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.4 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.4 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.4 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.4 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.4 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.4 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.4 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.4 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_import_type() raises:
    # v2.4 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.4 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_renaming_directives() raises:
    # v2.4 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_namespaced_directives() raises:
    # v2.4 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_repeatable_key() raises:
    # v2.4 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_interfaceobject() raises:
    # v2.4 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_extends() raises:
    # v2.4 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_override() raises:
    # v2.4 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.4 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.4 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_provides_itself_circular_reference() raises:
    # v2.4 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_external_provides() raises:
    # v2.4 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_external_requires() raises:
    # v2.4 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.4 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_external_tag() raises:
    # v2.4 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_tag() raises:
    # v2.4 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_tag_on_directive() raises:
    # v2.4 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.4 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.4 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.4 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.4 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.4 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.4 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.4 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.4 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.4 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.4 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.4 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_join_implements_on_interface_type() raises:
    # v2.4 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.4 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_scalars() raises:
    # v2.4 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_object_types() raises:
    # v2.4 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_fields_with_override_entity_types() raises:
    # v2.4 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.4 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_object_type_definition_with_extends() raises:
    # v2.4 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_object_types_with_arguments() raises:
    # v2.4 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_input_object_types() raises:
    # v2.4 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.4 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.4 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.4 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_union_types() raises:
    # v2.4 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_descriptions_on_interface_types() raises:
    # v2.4 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_deprecated_on_object_types() raises:
    # v2.4 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_deprecated_on_input_object_types() raises:
    # v2.4 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.4 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.4 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.4 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.4 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_federation_directives_and_types_link_and_join_spec() raises:
    # v2.4 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.4 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_two_exact_same_types() raises:
    # v2.5 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.5 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.5 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.5 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.5 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.5 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.5 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.5 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.5 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.5 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_object_types_with_different_fields() raises:
    # v2.5 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.5 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.5 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_interface_types_with_different_fields() raises:
    # v2.5 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.5 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_union_types_with_different_members() raises:
    # v2.5 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_input_types_and_field_arguments() raises:
    # v2.5 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_default_values_print() raises:
    # v2.5 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.5 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_5_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.5 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.5 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.5 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.5 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.5 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.5 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.5 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.5 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.5 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.5 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.5 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.5 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.5 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.5 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.5 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.5 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_requires_on_a_union_with_typename_fails() raises:
    # v2.5 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.5 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.5 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.5 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.5 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.5 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.5 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.5 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.5 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.5 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.5 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.5 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.5 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_import_type() raises:
    # v2.5 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.5 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_renaming_directives() raises:
    # v2.5 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_namespaced_directives() raises:
    # v2.5 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_repeatable_key() raises:
    # v2.5 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_interfaceobject() raises:
    # v2.5 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_extends() raises:
    # v2.5 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_override() raises:
    # v2.5 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.5 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.5 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_provides_itself_circular_reference() raises:
    # v2.5 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_external_provides() raises:
    # v2.5 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_external_requires() raises:
    # v2.5 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.5 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_external_tag() raises:
    # v2.5 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_tag() raises:
    # v2.5 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_tag_on_directive() raises:
    # v2.5 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.5 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.5 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.5 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.5 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.5 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.5 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.5 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.5 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.5 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.5 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.5 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_join_implements_on_interface_type() raises:
    # v2.5 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.5 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_scalars() raises:
    # v2.5 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_object_types() raises:
    # v2.5 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_fields_with_override_entity_types() raises:
    # v2.5 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.5 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_object_type_definition_with_extends() raises:
    # v2.5 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_object_types_with_arguments() raises:
    # v2.5 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_input_object_types() raises:
    # v2.5 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.5 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.5 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.5 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_union_types() raises:
    # v2.5 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_descriptions_on_interface_types() raises:
    # v2.5 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_deprecated_on_object_types() raises:
    # v2.5 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_deprecated_on_input_object_types() raises:
    # v2.5 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.5 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.5 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.5 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.5 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_federation_directives_and_types_link_and_join_spec() raises:
    # v2.5 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.5 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_two_exact_same_types() raises:
    # v2.6 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.6 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.6 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.6 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.6 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.6 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.6 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.6 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.6 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.6 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_object_types_with_different_fields() raises:
    # v2.6 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.6 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.6 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_interface_types_with_different_fields() raises:
    # v2.6 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.6 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_union_types_with_different_members() raises:
    # v2.6 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_input_types_and_field_arguments() raises:
    # v2.6 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_default_values_print() raises:
    # v2.6 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.6 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_6_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.6 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.6 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.6 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.6 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.6 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.6 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.6 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.6 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.6 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.6 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.6 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.6 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.6 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.6 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.6 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.6 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_requires_on_a_union_with_typename_fails() raises:
    # v2.6 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.6 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.6 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.6 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.6 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.6 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.6 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.6 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.6 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.6 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.6 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.6 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.6 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_import_type() raises:
    # v2.6 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.6 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_renaming_directives() raises:
    # v2.6 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_namespaced_directives() raises:
    # v2.6 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_repeatable_key() raises:
    # v2.6 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_interfaceobject() raises:
    # v2.6 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_extends() raises:
    # v2.6 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_override() raises:
    # v2.6 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.6 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.6 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_provides_itself_circular_reference() raises:
    # v2.6 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_external_provides() raises:
    # v2.6 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_external_requires() raises:
    # v2.6 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.6 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_external_tag() raises:
    # v2.6 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_tag() raises:
    # v2.6 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_tag_on_directive() raises:
    # v2.6 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.6 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.6 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.6 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.6 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.6 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.6 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.6 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.6 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.6 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.6 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.6 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_join_implements_on_interface_type() raises:
    # v2.6 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.6 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_scalars() raises:
    # v2.6 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_object_types() raises:
    # v2.6 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_fields_with_override_entity_types() raises:
    # v2.6 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.6 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_object_type_definition_with_extends() raises:
    # v2.6 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_object_types_with_arguments() raises:
    # v2.6 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_input_object_types() raises:
    # v2.6 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.6 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.6 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.6 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_union_types() raises:
    # v2.6 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_descriptions_on_interface_types() raises:
    # v2.6 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_deprecated_on_object_types() raises:
    # v2.6 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_deprecated_on_input_object_types() raises:
    # v2.6 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.6 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.6 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.6 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.6 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_federation_directives_and_types_link_and_join_spec() raises:
    # v2.6 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.6 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_two_exact_same_types() raises:
    # v2.7 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.7 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.7 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.7 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.7 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.7 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.7 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.7 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.7 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.7 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_object_types_with_different_fields() raises:
    # v2.7 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.7 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.7 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_interface_types_with_different_fields() raises:
    # v2.7 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.7 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_union_types_with_different_members() raises:
    # v2.7 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_input_types_and_field_arguments() raises:
    # v2.7 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_default_values_print() raises:
    # v2.7 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.7 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_7_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.7 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.7 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.7 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.7 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.7 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.7 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.7 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.7 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.7 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.7 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.7 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.7 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.7 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.7 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.7 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.7 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_requires_on_a_union_with_typename_fails() raises:
    # v2.7 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.7 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.7 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.7 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.7 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.7 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.7 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.7 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.7 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.7 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.7 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.7 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.7 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_import_type() raises:
    # v2.7 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.7 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_renaming_directives() raises:
    # v2.7 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_namespaced_directives() raises:
    # v2.7 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_repeatable_key() raises:
    # v2.7 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_interfaceobject() raises:
    # v2.7 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_extends() raises:
    # v2.7 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_override() raises:
    # v2.7 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.7 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.7 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_provides_itself_circular_reference() raises:
    # v2.7 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_external_provides() raises:
    # v2.7 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_external_requires() raises:
    # v2.7 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.7 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_external_tag() raises:
    # v2.7 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_tag() raises:
    # v2.7 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_tag_on_directive() raises:
    # v2.7 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.7 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.7 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.7 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.7 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.7 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.7 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.7 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.7 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.7 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.7 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.7 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_join_implements_on_interface_type() raises:
    # v2.7 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.7 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_scalars() raises:
    # v2.7 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_object_types() raises:
    # v2.7 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_fields_with_override_entity_types() raises:
    # v2.7 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.7 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_object_type_definition_with_extends() raises:
    # v2.7 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_object_types_with_arguments() raises:
    # v2.7 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_input_object_types() raises:
    # v2.7 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.7 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.7 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.7 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_union_types() raises:
    # v2.7 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_descriptions_on_interface_types() raises:
    # v2.7 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_deprecated_on_object_types() raises:
    # v2.7 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_deprecated_on_input_object_types() raises:
    # v2.7 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.7 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.7 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.7 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.7 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_federation_directives_and_types_link_and_join_spec() raises:
    # v2.7 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.7 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_two_exact_same_types() raises:
    # v2.8 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.8 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.8 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.8 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.8 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.8 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.8 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.8 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.8 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.8 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_object_types_with_different_fields() raises:
    # v2.8 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.8 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.8 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_interface_types_with_different_fields() raises:
    # v2.8 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.8 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_union_types_with_different_members() raises:
    # v2.8 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_input_types_and_field_arguments() raises:
    # v2.8 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_default_values_print() raises:
    # v2.8 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.8 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_8_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.8 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.8 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.8 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.8 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.8 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.8 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.8 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.8 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.8 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.8 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.8 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.8 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.8 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.8 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.8 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.8 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_requires_on_a_union_with_typename_fails() raises:
    # v2.8 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.8 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.8 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.8 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.8 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.8 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.8 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.8 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.8 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.8 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.8 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.8 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.8 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_import_type() raises:
    # v2.8 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.8 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_renaming_directives() raises:
    # v2.8 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_namespaced_directives() raises:
    # v2.8 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_repeatable_key() raises:
    # v2.8 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_interfaceobject() raises:
    # v2.8 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_extends() raises:
    # v2.8 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_override() raises:
    # v2.8 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.8 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.8 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_provides_itself_circular_reference() raises:
    # v2.8 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_external_provides() raises:
    # v2.8 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_external_requires() raises:
    # v2.8 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.8 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_external_tag() raises:
    # v2.8 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_tag() raises:
    # v2.8 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_tag_on_directive() raises:
    # v2.8 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.8 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.8 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.8 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.8 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.8 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.8 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.8 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.8 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.8 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.8 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.8 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_join_implements_on_interface_type() raises:
    # v2.8 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.8 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_scalars() raises:
    # v2.8 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_object_types() raises:
    # v2.8 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_fields_with_override_entity_types() raises:
    # v2.8 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.8 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_object_type_definition_with_extends() raises:
    # v2.8 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_object_types_with_arguments() raises:
    # v2.8 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_input_object_types() raises:
    # v2.8 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.8 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.8 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.8 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_union_types() raises:
    # v2.8 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_descriptions_on_interface_types() raises:
    # v2.8 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_deprecated_on_object_types() raises:
    # v2.8 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_deprecated_on_input_object_types() raises:
    # v2.8 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.8 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.8 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.8 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.8 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_federation_directives_and_types_link_and_join_spec() raises:
    # v2.8 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.8 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_two_exact_same_types() raises:
    # v2.9 > shareable > merge two exact same types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_same_type_with_same_fields_by_of_different_return_types_nul() raises:
    # v2.9 > shareable > merge same type with same fields by of different return types (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_same_types_but_one_has_an_extension() raises:
    # v2.9 > shareable > merge same types but one has an extension
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_same_types_but_one_has_an_extra_field() raises:
    # v2.9 > shareable > merge same types but one has an extra field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean!\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_extension_and_definition_of_object_type_and_print_extension() raises:
    # v2.9 > shareable > merge extension and definition of object type and print extension:true
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\nextend type User {\n  email: String! @shareable\n}\n\ntype Query {\n  user: User @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_same_types_but_one_has_an_extra_field_inaccessible() raises:
    # v2.9 > shareable > merge same types but one has an extra field (inaccessible)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\", \"@inaccessible\"])\n\ntype Food @shareable {\n  name: String!\n  price: Int!\n  inStock: Boolean! @inaccessible\n}\n\ntype Query {\n  food: Food\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_type_annotated_with_inaccessible_should_not_result_in_inaccessibl() raises:
    # v2.9 > shareable > type annotated with @inaccessible should not result in @inaccessible on its fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@inaccessible\"])\n\ntype Food @inaccessible {\n  name: String!\n  price: Int!\n}\n\ntype Drink @inaccessible {\n  name: String!\n  price: Int! @inaccessible\n}\n\ntype Query {\n  words: [String!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_an_argument_nullable_vs_missing() raises:
    # v2.9 > shareable > merge an argument (nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_an_argument_non_nullable_vs_missing() raises:
    # v2.9 > shareable > merge an argument (non-nullable vs missing)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_shareable_merge_an_argument_nullable_vs_non_nullable() raises:
    # v2.9 > shareable > merge an argument (nullable vs non-nullable)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String!): Int!\n}\n\ntype Query {\n  building: Building\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Building @shareable {\n  height(units: String): Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_object_types_with_different_fields() raises:
    # v2.9 > merge object types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.9 > merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_fed_v1_merge_object_extension_type_and_non_resolvable_object_type() raises:
    # v2.9 > Fed v1: merge object extension type and non-resolvable object type
    check(
        [
            sg(
                "a",
                "extend type User @key(fields: \"id\") {\n  id: ID @external\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_interface_types_with_different_fields() raises:
    # v2.9 > merge interface types with different fields
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\ninterface Details {\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Details {\n  email: String\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_union_types_with_different_members_some_are_overlapping() raises:
    # v2.9 > merge union types with different members (some are overlapping)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie | Book\n\ntype Movie {\n  title: String!\n}\n\ntype Book @shareable {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_union_types_with_different_members() raises:
    # v2.9 > merge union types with different members
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  email: String!\n}\n\nunion Media = Book\n\ntype Book @shareable {\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\nunion Media = Movie\n\ntype Movie {\n  title: String!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_input_types_and_field_arguments() raises:
    # v2.9 > merge input types and field arguments
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String!\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_default_values_print() raises:
    # v2.9 > default values > print
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ninput LibraryFilter {\n  limit: Int = 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  books(filter: LibraryFilter, access: LibraryAccess = PUBLIC): [String!]!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ninput UserFilter {\n  limit: Int = 10\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter, access: UserAccess = PRIVATE): [String!]!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ninput MediaFilter {\n  limit: Int = 15\n}\n\nenum MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\ninterface Media {\n  records(filter: MediaFilter, access: MediaAccess = PRIVATE): [String!]!\n}\n\ntype Movie implements Media {\n  records(filter: MediaFilter, access: MediaAccess = PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter: MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_default_values_collision_with_missing_default_value_on_directive_argument() raises:
    # v2.9 > default values > collision with missing default value on directive argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Directive \"@access\" argument \"scope\" of type \"Scope!\" is required, but it was not provided.",
        ],
    )


def test_v2_9_default_values_collision_with_different_default_value_on_directive_argument() raises:
    # v2.9 > default values > collision with different default value on directive argument for schema directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String @access\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String @access\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_default_values_collision_with_different_default_value_on_directive_argument_2() raises:
    # v2.9 > default values > collision with different default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PRIVATE) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_default_values_collision_with_missing_default_value_on_directive_argument_f() raises:
    # v2.9 > default values > collision with missing default value on directive argument for executable directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope!) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: Scope! = PUBLIC) on QUERY\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_default_values_collision_with_different_default_value_on_argument_on_field() raises:
    # v2.9 > default values > collision with different default value on argument on field argument
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PUBLIC): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\")\n\nenum Scope {\n  PUBLIC\n  PRIVATE\n}\n\ntype Query {\n  hello(scope: Scope! = PRIVATE): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_enum_type_types_when_used_as_the_return_type_for_at_least_one_object() raises:
    # v2.9 > merge enum type types when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument() raises:
    # v2.9 > merge enum type types when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_merge_enum_type_types_when_used_as_the_type_for_at_least_one_field_argument_2() raises:
    # v2.9 > merge enum type types when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_ignore_directive_if_not_defined_by_composedirective() raises:
    # v2.9 > ignore directive if not defined by @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @uppercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @uppercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_ignore_directive_if_identically_defined_in_all_subgraphs() raises:
    # v2.9 > ignore directive if identically defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Review @shareable {\n  name: String! @lowercase\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_ignore_directive_if_not_defined_in_all_subgraphs() raises:
    # v2.9 > ignore directive if not defined in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_ignore_directive_if_defined_differently_across_subgraphs() raises:
    # v2.9 > ignore directive if defined differently across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_ignore_directive_if_it_has_different_locations_across_subgraphs() raises:
    # v2.9 > ignore directive if it has different locations across subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @shareable {\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\ntype User @shareable @lowercase {\n  name: String!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_support_composedirective_when_using_multiple_schema_extensions() raises:
    # v2.9 > support @composeDirective when using multiple schema extensions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"])\n\nextend schema @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"])\n\nextend schema @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_if_not_defined_in_all_subgraphs_but_included_in_composed() raises:
    # v2.9 > preserve directive if not defined in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Query {\n  review: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_if_not_applied_on_a_field_in_all_subgraphs_but_included() raises:
    # v2.9 > preserve directive if not applied on a field in all subgraphs but included in @composeDirective
    check(
        [
            sg(
                "b",
                "directive @lowercase on FIELD_DEFINITION\n\nextend type Query {\n  \" users \"\n  users: [String] @lowercase @override(from: \"a\")\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\", \"@override\"]) @link(url: \"https://specs.community.graphql.org/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype Query {\n  users: [String]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\nextend type Query {\n  comments: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_ignore_directive_if_defined_identically_in_all_subgraphs_and_not_included_i() raises:
    # v2.9 > ignore directive if defined identically in all subgraphs and not included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype Comment @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_requires_on_a_union_with_typename_fails() raises:
    # v2.9 > @requires on a union with `__typename` fails
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  product(id: ID!): Product\n}\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description!\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String!\n}\n\ntype DescriptionShort {\n  value: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  description: Description! @external\n  calculatedField: String! @requires(fields: \"description { __typename ... on DescriptionLong { value } ... on DescriptionShort {value}} \")\n}\n\nunion Description = DescriptionLong | DescriptionShort\n\ntype DescriptionLong {\n  value: String! @external\n}\n\ntype DescriptionShort {\n  value: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # v2.9 > preserve directive from one subgraph if defined differently across subgraphs but one included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_if_defined_with_overlapping_locations_across_subgraphs_a() raises:
    # v2.9 > preserve directive if defined with overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_on_scalars_if_included_in_composedirective() raises:
    # v2.9 > preserve directive on scalars if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on SCALAR\n\nscalar DateTime @whatever\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: DateTime!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_on_enums_if_included_in_composedirective() raises:
    # v2.9 > preserve directive on enums if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM\n\nenum UserType @whatever {\n  ADMIN\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_on_enum_values_if_included_in_composedirective() raises:
    # v2.9 > preserve directive on enum values if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on ENUM_VALUE\n\nenum UserType {\n  ADMIN @whatever\n  REGULAR\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  type: UserType!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_on_union_types_if_included_in_composedirective() raises:
    # v2.9 > preserve directive on union types if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on UNION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\nunion Whoever @whatever = User | Admin\n\ntype Query {\n  whoever: [Whoever]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_on_interface_its_field_and_argument_if_included_in_compo() raises:
    # v2.9 > preserve directive on interface its field and argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\"]) @composeDirective(name: \"@whatever\")\n\ndirective @whatever on FIELD_DEFINITION | INTERFACE | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype AuthenticatedUser implements User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  createdAt: String!\n  tags(limit: Int): [String!]!\n}\n\ntype AnonymousUser implements User @key(fields: \"id\") {\n  id: ID!\n  tags(limit: Int): [String!]!\n}\n\ninterface User @whatever {\n  id: ID! @whatever\n  tags(limit: Int @whatever): [String!]!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # v2.9 > preserve directive on directive argument if included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/whatever/v1.0\", import: [\"@whatever\", \"@whenever\"]) @composeDirective(name: \"@whatever\") @composeDirective(name: \"@whenever\")\n\ndirective @whatever(when: String @whenever) on FIELD_DEFINITION\n\ndirective @whenever on ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when: \"now\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_use_highest_version_of_a_spec_that_imports_a_custom_directive_composedirect() raises:
    # v2.9 > use highest version of a spec that imports a custom directive (@composeDirective)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_two_different_major_versions_of_the_same_spec_were_used_to_import_a_scalar() raises:
    # v2.9 > two different major versions of the same spec were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_allow_to_compose_a_built_in_directive_oneof() raises:
    # v2.9 > allow to compose a built-in directive (@oneOf)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_two_different_specs_were_used_to_import_a_scalar_of_the_same_name() raises:
    # v2.9 > two different specs were used to import a scalar of the same name
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: LowercaseString!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"]) @link(url: \"https://yourspecs.dev/casing/v2.3\", import: [\"LowercaseString\"])\n\nscalar LowercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: LowercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_import_type() raises:
    # v2.9 > import type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [\"JSON\"])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"]) @link(url: \"https://myspecs.dev/json/v1.0\", import: [{name: \"JSON2\", as: \"JSON\"}])\n\nscalar JSON\n\ntype User @shareable {\n  name: JSON\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_every_entity_must_be_annotated_with_the_join_type_directive() raises:
    # v2.9 > every entity must be annotated with the @join__type directive
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_renaming_directives() raises:
    # v2.9 > renaming directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [{name: \"@key\", as: \"@primaryKey\"}])\n\ntype User @primaryKey(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_namespaced_directives() raises:
    # v2.9 > namespaced directives
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda @federation__key(fields: \"name\") {\n  name: ID!\n  favoriteFood: String\n}\n\ntype Details @federation__shareable {\n  createdAt: String\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_repeatable_key() raises:
    # v2.9 > repeatable @key
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") @key(fields: \"name\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}\n\ntype Query {\n  allUsers: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_interfaceobject() raises:
    # v2.9 > @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_extends() raises:
    # v2.9 > @extends
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Query {\n  books: [Book]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@extends\"])\n\ntype Book @key(fields: \"id\") @extends {\n  id: ID!\n  review: Review!\n}\n\ntype Review {\n  score: Int!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_override() raises:
    # v2.9 > @override
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Boolean! @override(from: \"a\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @override(from: \"main\")\n}",
            ),
            sg(
                "main",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@override\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_remove_provides_fields_when_all_fields_are_in_common_with_key_fields_and_pr() raises:
    # v2.9 > remove @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to a type extension
    check(
        [
            sg(
                "foo",
                "extend type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_preserve_provides_fields_when_all_fields_are_in_common_with_key_fields_and() raises:
    # v2.9 > preserve @provides(fields:) when all fields are in common with @key(fields:) and @provides refers to type definition
    check(
        [
            sg(
                "foo",
                "type User @key(fields: \"id\") {\n  id: String! @external\n}\n\ntype Group @key(fields: \"id\") {\n  id: ID\n  title: String\n  users: [User] @provides(fields: \"id\")\n}",
            ),
            sg(
                "bar",
                "extend type Group @key(fields: \"id\") {\n  id: ID @external\n  topic: Topic\n}\n\ntype Topic @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: String!\n  name: String\n}",
            ),
            sg(
                "baz",
                "type Theme @key(fields: \"id\") {\n  id: ID!\n  primaryColor: String\n}\n\ntype Query {\n  themes: [Theme]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_provides_itself_circular_reference() raises:
    # v2.9 > @provides itself - circular reference
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Query {\n  product: Product\n}\n\ninterface Product {\n  samePriceProduct: Product\n}\n\ntype Book implements Product @key(fields: \"id\") {\n  id: ID!\n  samePriceProduct: Book @provides(fields: \"price\")\n  price: Float @external\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n  price: Float @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_external_provides() raises:
    # v2.9 > @external + @provides
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@provides\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}\n\ntype Query {\n  outOfStockProducts: [Product!]! @provides(fields: \"name\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_external_requires() raises:
    # v2.9 > @external + @requires
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  inStock: Int!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_external_and_not_a_key_in_its_graph_but_is_key_in_other_graph() raises:
    # v2.9 > @external and not a @key in its graph, but is @key in other graph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @shareable {\n  id: ID!\n  productId: String!\n}\n\ntype Query {\n  products: [Product]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}",
            ),
            sg(
                "d",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\", \"@external\", \"@key\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id productId\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean\n}",
            ),
            sg(
                "e",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\nextend type Product @shareable @key(fields: \"id\") {\n  id: ID! @external\n  productId: String! @external\n  bField: Boolean @requires(fields: \"productId\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_external_tag() raises:
    # v2.9 > @external + @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  name: String! @tag(name: \"public\")\n  inStock: Int! @tag(name: \"public\")\n}\n\ntype Query {\n  products: [Product] @tag(name: \"public\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  inStock: Int! @external\n  isAvailable: String! @requires(fields: \"inStock\") @tag(name: \"public\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_tag() raises:
    # v2.9 > @tag
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\"])\n\ntype Query {\n  customer(id: String!): Customer @tag(name: \"team-customers\")\n  employee(id: String! @tag(name: \"team-admin\")): Employee @tag(name: \"team-admin\")\n  employees(filter: EmployeesFilter!): [Employee!] @tag(name: \"team-admin\")\n}\n\nscalar DateTime @tag(name: \"team-admin\")\n\ninterface User @tag(name: \"team-accounts\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Customer implements User @tag(name: \"team-customers\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n}\n\ntype Employee implements User @tag(name: \"team-admin\") {\n  id: String!\n  name(lowercase: Boolean @tag(name: \"team-accounts\")): String!\n  ssn: String!\n  createdAt: DateTime!\n}\n\ninput EmployeesFilter {\n  id: String @tag(name: \"team-admin\")\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_tag_on_directive() raises:
    # v2.9 > @tag on directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@tag\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/access/v1.0\", import: [\"@access\"]) @composeDirective(name: \"@access\")\n\ndirective @access(scope: String @tag(name: \"team-admin\")) on FIELD_DEFINITION\n\ntype Query {\n  employee(id: String!): Employee @tag(name: \"team-admin\") @access(scope: \"admin\")\n}\n\ntype Employee {\n  id: String!\n  name: String!\n  ssn: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_entity_annotated_with_key_directive_must_have_join_type_with_key_argument() raises:
    # v2.9 > entity annotated with @key directive must have @join__type with key argument
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n  role: Role!\n}\n\nenum Role {\n  ADMIN\n  USER\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_fields_referenced_by_key_directive_must_not_be_annotated_with_join_field() raises:
    # v2.9 > fields referenced by @key directive must NOT be annotated with @join__field
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_entity_used_by_more_than_one_service_must_be_annotated_with_join_type_of_th() raises:
    # v2.9 > entity used by more than one service must be annotated with @join__type of these service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_entity_directly_used_by_more_than_one_service_must_have_all_fields_annotate() raises:
    # v2.9 > entity directly used by more than one service must have all fields annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_a_field_of_an_entity_with_different_return_type_nullability_must_be_annotat() raises:
    # v2.9 > a field of an entity with different return type (nullability) must be annotated with multiple @join__field directives, each with original return type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int!\n  y: Int!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype Position @shareable {\n  x: Int\n  y: Int!\n}\n\ntype Query {\n  position: Position\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_a_field_of_an_entity_with_same_type_but_external_true_in_one_or_more_must_b() raises:
    # v2.9 > a field of an entity with same type but external:true in one or more must be annotated with multiple @join__field directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String!\n  discount: Int!\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ntype Product @key(fields: \"id name\") {\n  id: ID!\n  name: String! @external\n  reviews: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_enum_indirectly_used_by_more_than_one_service_must_have_all_values_annotate() raises:
    # v2.9 > enum indirectly used by more than one service must have all values annotated with @join__field directive, where `graph` argument points to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n  category: ProductCategory!\n}\n\ntype Price {\n  amount: Float\n}\n\nenum ProductCategory {\n  ALL\n  ELECTRONICS\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_query_must_be_annotated_with_join_type_directive_of_every_service() raises:
    # v2.9 > query must be annotated with @join__type directive of every service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to_th() raises:
    # v2.9 > all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@shareable\"])\n\nextend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product @shareable\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_v1_all_fields_of_query_object_must_be_annotated_with_join_field_pointing_to() raises:
    # v2.9 > [v1] all fields of query object must be annotated with @join__field pointing to the owning service
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  review(id: ID!): Review\n  product(id: ID!): Product\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external\n  reviews: [Review]\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "type Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_resolvable_false_should_be_passed_to_join_type_resolvable_false() raises:
    # v2.9 > @key(resolvable: false) should be passed to @join__type(resolvable: false)
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\", resolvable: false) {\n  id: ID!\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_join_implements_on_interface_type() raises:
    # v2.9 > @join__implements on Interface type
    check(
        [
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product implements Node & SellingItem @key(fields: \"id\") {\n  id: ID!\n  name: String!\n  price: Price!\n}\n\ninterface Node {\n  id: ID!\n}\n\ninterface SellingItem implements Node {\n  id: ID!\n  price: Price!\n}\n\ntype Price {\n  amount: Float\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_fed_v1_no_join_type_key_on_interface_type() raises:
    # v2.9 > Fed v1: no @join__type(key:) on interface type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product {\n  id: ID!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type User implements Node @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\ninterface Node @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_scalars() raises:
    # v2.9 > descriptions > on scalars
    check(
        [
            sg(
                "reviews",
                "extend type Query {\n  dateTime: DateTime\n}\n\n\"\"\"reviews\"\"\"\nscalar DateTime",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\nscalar DateTime\n\ntype Product @key(fields: \"id\") {\n  id: ID!\n  title: String\n  createdAt: DateTime\n}\n\nextend type Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_object_types() raises:
    # v2.9 > descriptions > on object types
    check(
        [
            sg(
                "a",
                "\"\"\"a\"\"\"\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "\"\"\"b\"\"\"\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(currency: String = \"USD\"): Price!\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_fields_with_override_entity_types() raises:
    # v2.9 > descriptions > on fields with @override (entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@requires\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n  aName: String! @requires(fields: \"name\")\n}\n\ntype Query {\n  userA: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @override(from: \"c\")\n}\n\ntype Query {\n  userB: User\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  id: ID!\n  \"it should not be in supergraph\"\n  name: String! @external\n}\n\ntype Foo @key(fields: \"id\") {\n  id: ID!\n  foo: String\n}\n\nscalar _Any\n\nunion _Entity = Foo | User\n\ntype _Service {\n  sdl: String!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n  _service: _Service\n  c: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_fields_with_override_not_entity_types() raises:
    # v2.9 > descriptions > on fields with @override (not entity types)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\", \"@override\", \"@key\"])\n\ntype User @shareable {\n  id: ID!\n  name: String! @override(from: \"b\")\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationA: Organization\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\", \"@key\"])\n\ntype User @shareable {\n  id: ID! @shareable\n  \"\"\"should be preserved\"\"\"\n  name: String! @shareable\n}\n\ntype Organization @key(fields: \"id\") {\n  id: ID!\n  owner: User @shareable\n}\n\ntype Query {\n  organizationB: Organization\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_object_type_definition_with_extends() raises:
    # v2.9 > descriptions > on object type definition with @extends
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@extends\"])\n\ntype Query {\n  review(id: ID!): Review\n}\n\n\"\"\"reviews\"\"\"\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"reviews\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  rating: Float\n  content: String\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n}\n\ntype Query {\n  product(id: ID!): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_object_types_with_arguments() raises:
    # v2.9 > descriptions > on object types with arguments
    check(
        [
            sg(
                "reviews",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@shareable\"])\n\n\"\"\"reviews\"\"\"\ntype Query {\n  \"\"\"reviews\"\"\"\n  review(\n    \"\"\"reviews\"\"\"\n    id: ID!\n  ): Review\n}\n\nextend type Product @key(fields: \"id\") {\n  \"\"\"it will be removed\"\"\"\n  id: ID! @external\n  \"\"\"reviews\"\"\"\n  reviews(\n    \"\"\"reviews\"\"\"\n    limit: Int\n  ): [Review]\n  \"\"\"reviews\"\"\"\n  price(\n    \"\"\"reviews\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"reviews\"\"\"\ntype Review @key(fields: \"id\") {\n  \"\"\"reviews\"\"\"\n  id: ID!\n  \"\"\"reviews\"\"\"\n  rating: Float\n  \"\"\"reviews\"\"\"\n  content: String\n}\n\n\"\"\"reviews\"\"\"\ntype Price {\n  \"\"\"reviews\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "pricing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@extends\", \"@shareable\"])\n\ntype Product @key(fields: \"id\") @extends {\n  \"\"\"pricing\"\"\"\n  id: ID! @external\n  promoCodes: [PromoCode]\n  \"\"\"pricing\"\"\"\n  price(\n    \"\"\"pricing\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\ntype PromoCode {\n  id: ID!\n  code: String!\n}\n\n\"\"\"pricing\"\"\"\ntype Price {\n  \"\"\"pricing\"\"\"\n  amount: Float @shareable\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\"])\n\n\"\"\"products\"\"\"\ntype Product @key(fields: \"id\") {\n  \"\"\"products\"\"\"\n  id: ID!\n  \"\"\"products\"\"\"\n  title: String\n  \"\"\"products\"\"\"\n  price(\n    \"\"\"products\"\"\"\n    currency: String = \"USD\"\n  ): Price! @shareable\n}\n\n\"\"\"products\"\"\"\ntype Price {\n  \"\"\"products\"\"\"\n  amount: Float @shareable\n}\n\ntype Query {\n  \"\"\"products\"\"\"\n  product(\n    \"\"\"products\"\"\"\n    id: ID!\n  ): Product\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_input_object_types() raises:
    # v2.9 > descriptions > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\n\"\"\"b\"\"\"\ninput UserInput {\n  \"\"\"b\"\"\"\n  name: String!\n  \"\"\"b\"\"\"\n  email: String\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ninput UserInput {\n  \"\"\"a\"\"\"\n  name: String!\n  \"\"\"a\"\"\"\n  age: Int\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_enum_types_when_used_as_the_return_type_for_at_least_one_ob() raises:
    # v2.9 > descriptions > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg() raises:
    # v2.9 > descriptions > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  \"\"\"a\"\"\"\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ANONYMOUS\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_enum_types_when_used_as_the_type_for_at_least_one_field_arg_2() raises:
    # v2.9 > descriptions > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"b\"\"\"\nenum UserType {\n  \"\"\"b\"\"\"\n  REGULAR\n  \"\"\"b\"\"\"\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\n\"\"\"a\"\"\"\nenum UserType {\n  \"\"\"a\"\"\"\n  ADMIN\n  REGULAR\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_union_types() raises:
    # v2.9 > descriptions > on union types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\nunion Media = Movie\n\ntype Movie {\n  id: ID!\n  title: String!\n}\n\ntype Admin @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\n\"\"\"c\"\"\"\nunion Media = Song\n\ntype Song {\n  id: ID!\n  title: String!\n}\n\ntype Anonymous @key(fields: \"id\") {\n  id: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\n\"\"\"b\"\"\"\nunion Media = Book\n\ntype Book {\n  id: ID!\n  title: String!\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  media(id: ID!): Media\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_descriptions_on_interface_types() raises:
    # v2.9 > descriptions > on interface types
    check(
        [
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  age: Int!\n}\n\n\"\"\"c\"\"\"\ninterface Details {\n  \"\"\"c\"\"\"\n  age: Int\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}\n\ninterface Details {\n  \"\"\"a\"\"\"\n  name: ID!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  email: String!\n}\n\n\"\"\"b\"\"\"\ninterface Details {\n  \"\"\"b\"\"\"\n  email: String\n  \"\"\"b\"\"\"\n  age: Int\n}\n\ntype Query {\n  user: User\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_deprecated_on_object_types() raises:
    # v2.9 > @deprecated > on object types
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\nextend type Query {\n  reviews(limit: Int @deprecated): [Review] @deprecated\n}\n\nextend type Product @key(fields: \"id\") {\n  id: ID! @external @deprecated(reason: \"a\")\n  reviews: [Review] @deprecated\n}\n\ntype Review @key(fields: \"id\") {\n  id: ID! @deprecated\n  rating: Float @deprecated\n  content: String @deprecated\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Product @key(fields: \"id\") {\n  id: ID! @deprecated(reason: \"b\")\n  title: String @deprecated\n  price: Price! @deprecated\n}\n\ntype Price {\n  amount: Float @deprecated\n}\n\nextend type Query {\n  product(id: ID!): Product @deprecated\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_deprecated_on_input_object_types() raises:
    # v2.9 > @deprecated > on input object types
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String @deprecated(reason: \"b\")\n  email: String @deprecated(reason: \"b\")\n}\n\ntype Library @shareable {\n  book(title: String, section: String): String\n}\n\ntype Query {\n  library: Library\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ninput UserInput {\n  name: String\n  email: String @deprecated(reason: \"a\")\n  age: Int @deprecated(reason: \"a\")\n}\n\ntype Library @shareable {\n  book(title: String, author: String): String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_deprecated_on_enum_types_when_used_as_the_return_type_for_at_least_one_obje() raises:
    # v2.9 > @deprecated > on enum types > when used as the return type for at least one object or interface field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum() raises:
    # v2.9 > @deprecated > on enum types > when used as the type for at least one field argument or input type field
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  ADMIN @deprecated(reason: \"a\")\n  REGULAR\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ANONYMOUS @deprecated(reason: \"b\")\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_deprecated_on_enum_types_when_used_as_the_type_for_at_least_one_field_argum_2() raises:
    # v2.9 > @deprecated > on enum types > when used as the type for at least one field argument or input type field and as the return type for at least one object or interface field
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  REGULAR @deprecated(reason: \"b\")\n  ADMIN\n}\n\ntype Query {\n  users(type: UserType): [User]\n}",
            ),
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String!\n  type: UserType\n}\n\nenum UserType {\n  ADMIN\n  REGULAR @deprecated(reason: \"a\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_enum_join_graph_must_contain_all_subgraphs_with_their_urls() raises:
    # v2.9 > enum join__Graph must contain all subgraphs with their URLs
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_federation_directives_and_types_link_and_join_spec() raises:
    # v2.9 > federation directives and types > link and join spec
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@shareable\"])\n\ntype User @shareable {\n  name: String\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_federation_directives_and_types_v1_link_and_join_spec() raises:
    # v2.9 > federation directives and types > [v1] link and join spec
    check(
        [
            sg(
                "a",
                "type User {\n  name: String\n}\n\ntype Query {\n  user: User\n}",
            ),
            sg(
                "b",
                "type Dog {\n  name: String\n}\n\ntype Query {\n  dog: Dog\n}",
            ),
        ],
        [
        ],
    )


def test_federation_v1_only_delete_subgraph_spec() raises:
    # Federation v1 only > delete subgraph spec
    check(
        [
            sg(
                "users",
                "type User {\n  name: String!\n  blocked: Boolean!\n}\n\ntype Query {\n  _entities(representations: [_Any!]!): [_Entity]!\n}\n\nextend type Query {\n  users: [User]!\n}\n\nextend type Query {\n  _service: _Service!\n}\n\nscalar _FieldSet\n\nscalar _Any\n\nunion _Entity = User\n\ntype _Service {\n  sdl: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "type User {\n  name: String!\n  blocked: Boolean!\n}\n\ntype RootQuery {\n  _entities(representations: [_Any!]!): [_Entity]!\n}\n\nschema {\n  query: RootQuery\n}\n\nextend type RootQuery {\n  users: [User]!\n}\n\nextend type RootQuery {\n  _service: _Service!\n}\n\nscalar _FieldSet\n\nscalar _Any\n\nunion _Entity = User\n\ntype _Service {\n  sdl: String\n}",
            ),
        ],
        [
        ],
    )


def test_federation_v1_only_tag_without_definition() raises:
    # Federation v1 only > @tag > without definition
    check(
        [
            sg(
                "users",
                "type User @key(fields: \"id\") {\n  id: ID!\n  name: String! @tag(name: \"private\")\n  blocked: Boolean!\n}\n\ntype Query {\n  users: [User]!\n}",
            ),
        ],
        [
        ],
    )


def test_federation_v1_only_tag_with_definition() raises:
    # Federation v1 only > @tag > with definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @tag(name: \"private\")\n  blocked: Boolean!\n}\n\ntype Query {\n  users: [User]!\n}",
            ),
        ],
        [
        ],
    )


def test_external_on_an_unused_field_in_an_extension_type() raises:
    # external on an unused field in an extension type
    check(
        [
            sg(
                "a",
                "type User @extends @key(fields: \"id\") {\n  a: String\n  id: ID! @external\n  uuid: ID! @external\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "type User @extends @key(fields: \"id\") {\n  b: String @requires(fields: \"uuid\")\n  id: ID! @external\n  uuid: ID! @external\n}\n\ntype Query {\n  b: String\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  c: String\n  id: ID!\n  uuid: ID!\n}\n\ntype Query {\n  c: User\n}",
            ),
            sg(
                "extra",
                "type Query {\n  extra: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User @extends @key(fields: \"id\") {\n  a: String\n  id: ID! @external\n  uuid: ID! @external\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "type User @extends @key(fields: \"id\") {\n  b: String @requires(fields: \"uuid\")\n  id: ID! @external\n  uuid: ID! @external\n}\n\ntype Query {\n  b: String\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") {\n  c: String\n  id: ID!\n  uuid: ID!\n}\n\ntype Query {\n  c: User\n}",
            ),
        ],
        [
        ],
    )


def test_fed_v1_external_on_a_provided_field_in_an_extension_type() raises:
    # Fed v1: external on a provided field in an extension type
    check(
        [
            sg(
                "a",
                "type User @key(fields: \"id\") @key(fields: \"uuid\") {\n  id: ID!\n  uuid: String!\n  name: String!\n}\n\ntype Query {\n  a: User\n}",
            ),
            sg(
                "b",
                "extend type User @key(fields: \"uuid\") {\n  uuid: String! @external\n}\n\ntype B {\n  id: ID!\n  user: User!\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") @key(fields: \"uuid\") {\n  id: ID!\n  uuid: String!\n  commentCount: Int!\n}",
            ),
            sg(
                "d",
                "extend type User @key(fields: \"uuid\") {\n  uuid: String! @external\n  id: ID! @external\n}\n\ntype D {\n  id: ID!\n  user: User! @provides(fields: \"id\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type User @key(fields: \"id\") @key(fields: \"uuid\") {\n  id: ID!\n  uuid: String!\n  name: String!\n}\n\ntype Query {\n  a: User\n}",
            ),
            sg(
                "b",
                "extend type User @key(fields: \"uuid\") {\n  uuid: String! @external\n}\n\ntype B {\n  id: ID!\n  user: User!\n}",
            ),
            sg(
                "c",
                "type User @key(fields: \"id\") @key(fields: \"uuid\") {\n  id: ID!\n  uuid: String!\n  commentCount: Int!\n}",
            ),
            sg(
                "d",
                "extend type User @key(fields: \"uuid\") {\n  uuid: String! @external\n  id: ID! @external\n}\n\ntype D {\n  id: ID!\n  user: User! @provides(fields: \"id\")\n}",
            ),
            sg(
                "extra",
                "type Query {\n  extra: String!\n}",
            ),
        ],
        [
        ],
    )


def test_unused_external_on_key_field_of_an_entity_type() raises:
    # unused external on key-field of an entity type
    check(
        [
            sg(
                "a",
                "type Site @key(fields: \"header\") @key(fields: \"footer\") {\n  header: String @external\n  footer: String @external\n  headerTitle: String\n  footerTitle: String\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "type Site @key(fields: \"id\") {\n  id: ID!\n  header: String\n  footer: String\n  title: String\n}\n\ntype Query {\n  site: Site\n}",
            ),
            sg(
                "c",
                "type Site @key(fields: \"id\") {\n  id: ID!\n  tag: String\n}\n\ntype Query {\n  c: Site\n}",
            ),
            sg(
                "extra",
                "type Query {\n  extra: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "type Site @key(fields: \"header\") @key(fields: \"footer\") {\n  header: String @external\n  footer: String @external\n  headerTitle: String\n  footerTitle: String\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "type Site @key(fields: \"id\") {\n  id: ID!\n  header: String\n  footer: String\n  title: String\n}\n\ntype Query {\n  site: Site\n}",
            ),
            sg(
                "c",
                "type Site @key(fields: \"id\") {\n  id: ID!\n  tag: String\n}\n\ntype Query {\n  c: Site\n}",
            ),
        ],
        [
        ],
    )


def test_external_on_non_key_field_of_an_entity_type() raises:
    # external on non-key field of an entity type
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@requires\", \"@tag\"])\n\ntype User @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  creditScore: Int @requires(fields: \"ssn\") @tag(name: \"public\")\n}\n\nextend type User @external {\n  ssn: String\n}",
            ),
            sg(
                "b",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@tag\"]) {\n  query: Query\n}\n\ntype Query {\n  user: User @tag(name: \"public\")\n}\n\ntype User @key(fields: \"id\") {\n  id: ID! @tag(name: \"public\")\n  ssn: String\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\", \"@shareable\"])\n\ntype Note @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @external\n  author: User @external\n}\n\ntype User @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype PrivateNote @key(fields: \"id\") @shareable {\n  id: ID!\n  note: Note @provides(fields: \"name author { id }\")\n}\n\ntype Query {\n  note: Note @shareable\n  privateNote: PrivateNote @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Note @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n  author: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype PrivateNote @key(fields: \"id\") @shareable {\n  id: ID!\n  note: Note\n}\n\ntype Query {\n  note: Note @shareable\n  privateNote: PrivateNote @shareable\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "foo",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\", \"@shareable\"])\n\ntype Note @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String @external\n  author: User @external\n}\n\ntype User @key(fields: \"id\", resolvable: false) {\n  id: ID!\n}\n\ntype PrivateNote @key(fields: \"id\") @shareable {\n  id: ID!\n  note: Note @provides(fields: \"name author { id }\")\n}\n\ntype Query {\n  note: Note @shareable\n  privateNote: PrivateNote @shareable\n}",
            ),
            sg(
                "bar",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Note @key(fields: \"id\") @shareable {\n  id: ID!\n  name: String\n  author: User\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype PrivateNote @key(fields: \"id\") @shareable {\n  id: ID!\n  note: Note\n}\n\ntype Query {\n  note: Note @shareable\n  privateNote: PrivateNote @shareable\n}",
            ),
            sg(
                "baz",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@provides\", \"@shareable\"])\n\ntype Query {\n  hello: String\n}\n\ntype Note @key(fields: \"id\") @shareable {\n  id: ID!\n  tag: String\n}",
            ),
        ],
        [
        ],
    )


def test_print_join_field_external_the_field_is_required_in_a_deeply_nested_selection_set() raises:
    # print join__field external the field is required in a deeply nested selection set
    check(
        [
            sg(
                "a",
                "type Query {\n  a: String\n}\n\ntype User {\n  id: ID!\n  age: Int!\n  name: String!\n}",
            ),
            sg(
                "b",
                "type Query {\n  b: String\n}\n\ntype Book {\n  author: User @requires(fields: \"author { name }\")\n}\n\nextend type User {\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_query_field_with_override_that_points_to_non_existing_subgraph() raises:
    # Query field with @override that points to non-existing subgraph
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@override\"])\n\ntype Query {\n  a: String @override(from: \"non-existing\")\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@override\"])\n\ntype Query {\n  a: String @override(from: \"non-existing\")\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@override\"])\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_drop_unused_external_fields_from_federation_v1_subgraphs() raises:
    # drop unused external fields from Federation v1 subgraphs
    check(
        [
            sg(
                "a",
                "type User @key(fields: \"id\") {\n  id: ID!\n  name: String @external\n  age: Int!\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "type User @key(fields: \"id\") {\n  id: ID!\n  age: Int! @external\n  birthday: String @requires(fields: \"age\")\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_join_field_usedoverridden_true_on_a_field_that_is_a_key_field_but_not_external() raises:
    # join__field(usedOverridden: true) on a field that is a key field but not external
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"userId\") {\n  userId: ID! @override(from: \"b\")\n  age: Int! @override(from: \"b\")\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ntype User @key(fields: \"userId\") {\n  userId: ID!\n  age: Int!\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_deduplicates_directives() raises:
    # deduplicates directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION | ENUM\n\ntype User @key(fields: \"id\") {\n  id: ID! @lowercase\n  age: Int!\n  type: UserType! @shareable\n}\n\nenum UserType @lowercase {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  a: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\", \"@shareable\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION | ENUM\n\ntype User @key(fields: \"id\") {\n  id: ID! @lowercase\n  age: Int! @external\n  birthday: String @requires(fields: \"age\")\n  type: UserType! @lowercase @shareable\n}\n\nenum UserType @lowercase {\n  REGULAR\n  ADMIN\n}\n\ntype Query {\n  b: String\n}",
            ),
        ],
        [
        ],
    )


def test_reproduction_gw_164_empty_list_as_a_non_nullable_enum_value_argument_of_a_direct() raises:
    # reproduction: GW-164 - empty list as a non-nullable enum value argument of a directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\"]) @composeDirective(name: \"@myDirective\")\n\ndirective @myDirective(myarg: [MyEnum!]!) on OBJECT\n\nenum MyEnum {\n  MY_ENUM_VALUE\n}\n\ntype Query {\n  myRootField: MyObject\n}\n\ntype MyObject @myDirective(myarg: []) {\n  myField: String\n}",
            ),
        ],
        [
        ],
    )


def test_tag_usage_without_name_argument_raises_no_exception() raises:
    # @tag usage without 'name' argument raises no exception
    check(
        [
            sg(
                "a service",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@tag\"])\n\ntype Query {\n  ping: String\n  pong: String\n  foo: User @tag\n}\n\ntype User {\n  id: ID!\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a service] Directive \"@tag\" argument \"name\" of type \"String!\" is required, but it was not provided.",
        ],
    )


def test_tag_usage_with_wrong_name_argument_type_raises_no_exception() raises:
    # @tag usage with wrong 'name' argument type raises no exception
    check(
        [
            sg(
                "a service",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@tag\"])\n\ntype Query {\n  ping: String\n  pong: String\n  foo: User @tag(name: {})\n}\n\ntype User {\n  id: ID!\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a service] Invalid value for \"@tag(name:)\" of type \"String!\" in application of \"@tag\" to \"Query.foo\".",
        ],
    )


def test_inaccessible_interface_implemented_by_accessible_types() raises:
    # inaccessible interface implemented by accessible types
    check(
        [
            sg(
                "FOO_GRAPHQL",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@inaccessible\"]) {\n  query: Query\n}\n\ntype Query {\n  public: PublicAccessTokenConnection!\n  private: PrivateAccessTokenConnection! @inaccessible\n}\n\ninterface AccessToken @inaccessible {\n  id: ID!\n}\n\ninterface AccessTokenEdge @inaccessible {\n  node: AccessToken!\n}\n\ninterface AccessTokenConnection @inaccessible {\n  edges: [AccessTokenEdge!]!\n}\n\ntype PrivateAccessToken implements AccessToken @inaccessible {\n  id: ID!\n}\n\ntype PrivateAccessTokenEdge implements AccessTokenEdge @inaccessible {\n  node: PrivateAccessToken!\n}\n\ntype PrivateAccessTokenConnection implements AccessTokenConnection @inaccessible {\n  edges: [PrivateAccessTokenEdge!]!\n}\n\ntype PublicAccessToken implements AccessToken {\n  id: ID!\n}\n\ntype PublicAccessTokenEdge implements AccessTokenEdge {\n  node: PublicAccessToken!\n}\n\ntype PublicAccessTokenConnection implements AccessTokenConnection {\n  edges: [PublicAccessTokenEdge!]!\n}",
            ),
        ],
        [
        ],
    )


def test_fieldset_does_not_leak_as_external_type_onto_supergraph_if_defined_in_subgraph() raises:
    # FieldSet does not leak as external type onto supergraph if defined in subgraph
    check(
        [
            sg(
                "a",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n  mutation: Mutation\n}\n\ninterface Node {\n  id: ID!\n}\n\ntype Mutation {\n  _: String\n}\n\ntype Query {\n  node(id: ID!): Node\n  _service: _Service!\n  _entities(representations: [_Any!]!): [_Entity]!\n}\n\ntype User implements Node @key(fields: \"id\") @key(fields: \"username\") {\n  id: ID!\n  username: String\n}\n\ntype _Service {\n  sdl: String!\n}\n\nunion _Entity = User\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ndirective @link(url: String!, import: [String!]) repeatable on SCHEMA\n\nscalar FieldSet\n\nscalar Long\n\nscalar _Any",
            ),
        ],
        [
        ],
    )


def test_keeps_join_field_for_object_type_extension_with_key_being_external() raises:
    # keeps @join__field for object type extension with @key being @external
    check(
        [
            sg(
                "owner-service",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Repository @key(fields: \"id name\") {\n  id: ID! @external\n  name: String! @external\n}",
            ),
            sg(
                "team-service",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Repository @key(fields: \"id\") {\n  id: ID! @external\n}",
            ),
            sg(
                "repo-service",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  repo: Repository\n}\n\ntype Repository @key(fields: \"id\") {\n  id: ID!\n  name: String! @shareable\n}",
            ),
        ],
        [
        ],
    )


def test_keep_join_field_for_object_type_extension_where_key_is_external_and_have_other_e() raises:
    # keep @join__field for object type extension where @key is @external and have other @external fields used with @requires
    check(
        [
            sg(
                "developer-service",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\"])\n\ntype Query {\n  me: Developer\n}\n\ntype Developer @key(fields: \"id\") @key(fields: \"guestGuid\") {\n  id: ID!\n  guestGuid: ID! @shareable\n  isMe: Boolean! @shareable\n  myFollowingStatus: String! @shareable\n  userVisibility: String! @shareable\n}",
            ),
            sg(
                "team-service",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\nextend type Developer @key(fields: \"guestGuid\") {\n  guestGuid: ID! @external\n  myFollowingStatus: String! @external\n  userVisibility: String! @external\n  guestSavedLists: [ID!]! @requires(fields: \"myFollowingStatus userVisibility\")\n}",
            ),
            sg(
                "commit-service",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\nextend type Developer @key(fields: \"id\") {\n  id: ID! @external\n  isMe: Boolean! @external\n  userVisibility: String! @external\n  commits: [ID!]! @requires(fields: \"isMe userVisibility\")\n}",
            ),
            sg(
                "reaction-service",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\nextend type Developer @key(fields: \"id\") {\n  id: ID! @external\n}",
            ),
        ],
        [
        ],
    )


def test_external_on_non_key_field_in_federation_v1() raises:
    # @external on non-key field in Federation v1
    check(
        [
            sg(
                "users",
                "type Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "extra",
                "type User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_external_on_non_key_field_in_federation_v2() raises:
    # @external on non-key field in Federation v2
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
            sg(
                "extra",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_external_object_type_field_implementing_interface_field() raises:
    # @external object type field implementing interface field
    check(
        [
            sg(
                "github_core",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  checks: QueuedCheckRunInfo\n}\n\ninterface CheckRunInfo {\n  id: ID!\n  status: String!\n}\n\ntype QueuedCheckRunInfo implements CheckRunInfo @key(fields: \"id\") {\n  id: ID!\n  status: String!\n  commitOid: String!\n}",
            ),
            sg(
                "github_action",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@requires\"])\n\nextend type QueuedCheckRunInfo implements CheckRunInfo @key(fields: \"id\") {\n  id: ID! @external\n  status: String! @external\n  commitOid: String! @external\n  workflowRunId: ID! @requires(fields: \"commitOid\")\n}\n\ninterface CheckRunInfo {\n  id: ID!\n  status: String!\n}",
            ),
        ],
        [
        ],
    )


def test_guild_composition_oneof_supports_composing_built_in_directive() raises:
    # guild composition (@oneOf) > supports composing built-in directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_guild_composition_oneof_supports_composing_built_in_directive_with_matching_defi() raises:
    # guild composition (@oneOf) > supports composing built-in directive (with matching definition)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @oneOf on INPUT_OBJECT\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
        ],
        [
        ],
    )


def test_guild_composition_oneof_merges_built_in_oneof_with_an_explicitly_linked_and_comp() raises:
    # guild composition (@oneOf) > merges built-in @oneOf with an explicitly linked and composed @oneOf definition
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT\n\ntype Hello {\n  world: String\n}\n\ntype Query {\n  greetings(input: GreetingsInput!): [Hello]\n}\n\ninput GreetingsInput @oneOf {\n  hello: String\n  world: String\n}",
            ),
        ],
        [
        ],
    )


def test_guild_composition_oneof_composes_successfully_when_a_composed_manual_definition() raises:
    # guild composition (@oneOf) > composes successfully when a composed manual definition widens specified directive locations
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ndirective @oneOf on INPUT_OBJECT\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT | OBJECT\n\ntype Hello @oneOf {\n  world: String\n}\n\ntype Query {\n  greetings: [Hello]\n}",
            ),
        ],
        [
        ],
    )


def test_guild_composition_oneof_composition_fails_when_a_composed_directive_definitions() raises:
    # guild composition (@oneOf) > composition fails when a composed directive definitions are not compatible with specified @oneOf
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ninput HelloInput @oneOf {\n  world: String\n  me: String\n}\n\ntype Query {\n  hello(input: HelloInput): String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on OBJECT\n\ntype Hello @oneOf {\n  world: String\n}\n\ntype Query {\n  greetings: [Hello]\n}",
            ),
        ],
        [
        ],
    )


def test_guild_composition_oneof_composes_successfully_when_a_single_subgraph_widens_a_sp() raises:
    # guild composition (@oneOf) > composes successfully when a single subgraph widens a specified directive location
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://spec.graphql.org/specified/v1.6\", import: [\"@oneOf\"]) @composeDirective(name: \"@oneOf\")\n\ndirective @oneOf on INPUT_OBJECT | OBJECT\n\ntype Hello @oneOf {\n  world: String\n}\n\ntype Query {\n  greetings: [Hello]\n}",
            ),
        ],
        [
        ],
    )


def test_guild_composition_oneof_strips_custom_oneof_execution_locations_from_the_compose() raises:
    # guild composition (@oneOf) > strips custom @oneOf execution locations from the composed SDL if it is not explicitly composed
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @oneOf on INPUT_OBJECT | OBJECT\n\ntype Hello @oneOf {\n  world: String\n}\n\ntype Query {\n  greetings: [Hello]\n}",
            ),
        ],
        [
        ],
    )


def test_guild_composition_oneof_allows_an_uncomposed_oneof_matching_the_spec_to_surface() raises:
    # guild composition (@oneOf) > allows an uncomposed @oneOf matching the spec to surface implicitly on public input objects
    check(
        [
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @oneOf on INPUT_OBJECT\n\ninput GreetingsInput @oneOf {\n  hello: String\n  world: String\n}\n\ntype Query {\n  greetings(input: GreetingsInput!): String\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
