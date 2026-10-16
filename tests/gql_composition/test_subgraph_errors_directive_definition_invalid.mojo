# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/DIRECTIVE_DEFINITION_INVALID.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.0 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.0 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_0_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.0 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_external_exact_same_definition_with_an_import() raises:
    # v2.0 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_0_external_no_object() raises:
    # v2.0 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_0_external_no_field_definition() raises:
    # v2.0 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_0_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.0 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_0_tag_exact_same_definition_with_import() raises:
    # v2.0 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_0_inaccessible_exact_same_definition_and_imported() raises:
    # v2.0 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_0_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.0 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_override_exact_same_definition_and_imported() raises:
    # v2.0 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_0_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.0 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.0 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_fields_of_string_type() raises:
    # v2.0 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_fields_of_different_type() raises:
    # v2.0 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_0_key_federation_fieldset_should_be_accepted() raises:
    # v2.0 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.0 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_missing_default_value_for_resolvable() raises:
    # v2.0 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_0_key_missing_resolvable() raises:
    # v2.0 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_missing_fields() raises:
    # v2.0 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_0_key_missing_repeatable() raises:
    # v2.0 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_not_on_interface() raises:
    # v2.0 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_not_on_object() raises:
    # v2.0 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_key_on_field() raises:
    # v2.0 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_0_key_fed_v1_uses_fieldset() raises:
    # v2.0 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_0_requires_should_be_ignored_if_not_imported() raises:
    # v2.0 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_requires_exact_definition() raises:
    # v2.0 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_requires_fields_of_string_type() raises:
    # v2.0 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_0_requires_fields_of_different_type() raises:
    # v2.0 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_0_requires_missing_fields() raises:
    # v2.0 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_0_requires_on_object() raises:
    # v2.0 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_1_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.1 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.1 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_1_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.1 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_external_exact_same_definition_with_an_import() raises:
    # v2.1 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_1_external_no_object() raises:
    # v2.1 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_1_external_no_field_definition() raises:
    # v2.1 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_1_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.1 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_1_tag_exact_same_definition_with_import() raises:
    # v2.1 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_1_inaccessible_exact_same_definition_and_imported() raises:
    # v2.1 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_1_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.1 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_override_exact_same_definition_and_imported() raises:
    # v2.1 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_1_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.1 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.1 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_fields_of_string_type() raises:
    # v2.1 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_fields_of_different_type() raises:
    # v2.1 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_1_key_federation_fieldset_should_be_accepted() raises:
    # v2.1 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.1 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_missing_default_value_for_resolvable() raises:
    # v2.1 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_1_key_missing_resolvable() raises:
    # v2.1 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_missing_fields() raises:
    # v2.1 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_1_key_missing_repeatable() raises:
    # v2.1 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_not_on_interface() raises:
    # v2.1 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_not_on_object() raises:
    # v2.1 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_key_on_field() raises:
    # v2.1 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_1_key_fed_v1_uses_fieldset() raises:
    # v2.1 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_1_requires_should_be_ignored_if_not_imported() raises:
    # v2.1 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_requires_exact_definition() raises:
    # v2.1 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_requires_fields_of_string_type() raises:
    # v2.1 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_requires_fields_of_different_type() raises:
    # v2.1 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_1_requires_missing_fields() raises:
    # v2.1 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_1_requires_on_object() raises:
    # v2.1 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_2_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.2 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.2 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_2_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.2 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_external_exact_same_definition_with_an_import() raises:
    # v2.2 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_2_external_no_object() raises:
    # v2.2 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_2_external_no_field_definition() raises:
    # v2.2 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_2_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.2 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_2_tag_exact_same_definition_with_import() raises:
    # v2.2 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_2_inaccessible_exact_same_definition_and_imported() raises:
    # v2.2 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_2_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.2 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_override_exact_same_definition_and_imported() raises:
    # v2.2 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_2_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.2 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.2 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_fields_of_string_type() raises:
    # v2.2 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_fields_of_different_type() raises:
    # v2.2 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_2_key_federation_fieldset_should_be_accepted() raises:
    # v2.2 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.2 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_missing_default_value_for_resolvable() raises:
    # v2.2 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_2_key_missing_resolvable() raises:
    # v2.2 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_missing_fields() raises:
    # v2.2 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_2_key_missing_repeatable() raises:
    # v2.2 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_not_on_interface() raises:
    # v2.2 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_not_on_object() raises:
    # v2.2 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_key_on_field() raises:
    # v2.2 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_2_key_fed_v1_uses_fieldset() raises:
    # v2.2 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_2_requires_should_be_ignored_if_not_imported() raises:
    # v2.2 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_requires_exact_definition() raises:
    # v2.2 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_requires_fields_of_string_type() raises:
    # v2.2 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_requires_fields_of_different_type() raises:
    # v2.2 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_2_requires_missing_fields() raises:
    # v2.2 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_2_requires_on_object() raises:
    # v2.2 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_3_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.3 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.3 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_3_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.3 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_external_exact_same_definition_with_an_import() raises:
    # v2.3 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_3_external_no_object() raises:
    # v2.3 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_3_external_no_field_definition() raises:
    # v2.3 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_3_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.3 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_3_tag_exact_same_definition_with_import() raises:
    # v2.3 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_3_inaccessible_exact_same_definition_and_imported() raises:
    # v2.3 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_3_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.3 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_override_exact_same_definition_and_imported() raises:
    # v2.3 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_3_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.3 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.3 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_fields_of_string_type() raises:
    # v2.3 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_fields_of_different_type() raises:
    # v2.3 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_3_key_federation_fieldset_should_be_accepted() raises:
    # v2.3 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.3 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_missing_default_value_for_resolvable() raises:
    # v2.3 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_3_key_missing_resolvable() raises:
    # v2.3 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_missing_fields() raises:
    # v2.3 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_3_key_missing_repeatable() raises:
    # v2.3 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_not_on_interface() raises:
    # v2.3 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_not_on_object() raises:
    # v2.3 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_key_on_field() raises:
    # v2.3 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_3_key_fed_v1_uses_fieldset() raises:
    # v2.3 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_3_requires_should_be_ignored_if_not_imported() raises:
    # v2.3 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_requires_exact_definition() raises:
    # v2.3 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_requires_fields_of_string_type() raises:
    # v2.3 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_requires_fields_of_different_type() raises:
    # v2.3 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_3_requires_missing_fields() raises:
    # v2.3 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_3_requires_on_object() raises:
    # v2.3 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_4_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.4 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.4 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_4_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.4 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_external_exact_same_definition_with_an_import() raises:
    # v2.4 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_4_external_no_object() raises:
    # v2.4 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_4_external_no_field_definition() raises:
    # v2.4 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_4_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.4 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_4_tag_exact_same_definition_with_import() raises:
    # v2.4 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_4_inaccessible_exact_same_definition_and_imported() raises:
    # v2.4 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_4_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.4 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_override_exact_same_definition_and_imported() raises:
    # v2.4 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_4_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.4 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.4 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_fields_of_string_type() raises:
    # v2.4 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_fields_of_different_type() raises:
    # v2.4 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_4_key_federation_fieldset_should_be_accepted() raises:
    # v2.4 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.4 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_missing_default_value_for_resolvable() raises:
    # v2.4 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_4_key_missing_resolvable() raises:
    # v2.4 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_missing_fields() raises:
    # v2.4 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_4_key_missing_repeatable() raises:
    # v2.4 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_not_on_interface() raises:
    # v2.4 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_not_on_object() raises:
    # v2.4 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_key_on_field() raises:
    # v2.4 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_4_key_fed_v1_uses_fieldset() raises:
    # v2.4 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_4_requires_should_be_ignored_if_not_imported() raises:
    # v2.4 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_requires_exact_definition() raises:
    # v2.4 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_requires_fields_of_string_type() raises:
    # v2.4 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_requires_fields_of_different_type() raises:
    # v2.4 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_4_requires_missing_fields() raises:
    # v2.4 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_4_requires_on_object() raises:
    # v2.4 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_5_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.5 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.5 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_5_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.5 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_external_exact_same_definition_with_an_import() raises:
    # v2.5 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_5_external_no_object() raises:
    # v2.5 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_5_external_no_field_definition() raises:
    # v2.5 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_5_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.5 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_5_tag_exact_same_definition_with_import() raises:
    # v2.5 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_5_inaccessible_exact_same_definition_and_imported() raises:
    # v2.5 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_5_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.5 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_override_exact_same_definition_and_imported() raises:
    # v2.5 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_5_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.5 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.5 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_fields_of_string_type() raises:
    # v2.5 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_fields_of_different_type() raises:
    # v2.5 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_5_key_federation_fieldset_should_be_accepted() raises:
    # v2.5 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.5 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_missing_default_value_for_resolvable() raises:
    # v2.5 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_5_key_missing_resolvable() raises:
    # v2.5 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_missing_fields() raises:
    # v2.5 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_5_key_missing_repeatable() raises:
    # v2.5 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_not_on_interface() raises:
    # v2.5 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_not_on_object() raises:
    # v2.5 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_key_on_field() raises:
    # v2.5 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_5_key_fed_v1_uses_fieldset() raises:
    # v2.5 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_5_requires_should_be_ignored_if_not_imported() raises:
    # v2.5 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_requires_exact_definition() raises:
    # v2.5 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_requires_fields_of_string_type() raises:
    # v2.5 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_requires_fields_of_different_type() raises:
    # v2.5 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_5_requires_missing_fields() raises:
    # v2.5 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_5_requires_on_object() raises:
    # v2.5 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_6_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.6 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.6 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_6_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.6 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_external_exact_same_definition_with_an_import() raises:
    # v2.6 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_6_external_no_object() raises:
    # v2.6 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_6_external_no_field_definition() raises:
    # v2.6 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_6_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.6 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_6_tag_exact_same_definition_with_import() raises:
    # v2.6 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_6_inaccessible_exact_same_definition_and_imported() raises:
    # v2.6 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_6_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.6 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_override_exact_same_definition_and_imported() raises:
    # v2.6 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_6_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.6 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.6 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_fields_of_string_type() raises:
    # v2.6 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_fields_of_different_type() raises:
    # v2.6 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_6_key_federation_fieldset_should_be_accepted() raises:
    # v2.6 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.6 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_missing_default_value_for_resolvable() raises:
    # v2.6 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_6_key_missing_resolvable() raises:
    # v2.6 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_missing_fields() raises:
    # v2.6 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_6_key_missing_repeatable() raises:
    # v2.6 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_not_on_interface() raises:
    # v2.6 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_not_on_object() raises:
    # v2.6 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_key_on_field() raises:
    # v2.6 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_6_key_fed_v1_uses_fieldset() raises:
    # v2.6 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_6_requires_should_be_ignored_if_not_imported() raises:
    # v2.6 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_requires_exact_definition() raises:
    # v2.6 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_requires_fields_of_string_type() raises:
    # v2.6 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_requires_fields_of_different_type() raises:
    # v2.6 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_6_requires_missing_fields() raises:
    # v2.6 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_6_requires_on_object() raises:
    # v2.6 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_7_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.7 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.7 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_7_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.7 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_external_exact_same_definition_with_an_import() raises:
    # v2.7 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_7_external_no_object() raises:
    # v2.7 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_7_external_no_field_definition() raises:
    # v2.7 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_7_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.7 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_7_tag_exact_same_definition_with_import() raises:
    # v2.7 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_7_inaccessible_exact_same_definition_and_imported() raises:
    # v2.7 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_7_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.7 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_override_exact_same_definition_and_imported() raises:
    # v2.7 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_7_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.7 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.7 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_fields_of_string_type() raises:
    # v2.7 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_fields_of_different_type() raises:
    # v2.7 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_7_key_federation_fieldset_should_be_accepted() raises:
    # v2.7 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.7 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_missing_default_value_for_resolvable() raises:
    # v2.7 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_7_key_missing_resolvable() raises:
    # v2.7 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_missing_fields() raises:
    # v2.7 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_7_key_missing_repeatable() raises:
    # v2.7 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_not_on_interface() raises:
    # v2.7 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_not_on_object() raises:
    # v2.7 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_key_on_field() raises:
    # v2.7 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_7_key_fed_v1_uses_fieldset() raises:
    # v2.7 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_7_requires_should_be_ignored_if_not_imported() raises:
    # v2.7 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_requires_exact_definition() raises:
    # v2.7 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_requires_fields_of_string_type() raises:
    # v2.7 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_requires_fields_of_different_type() raises:
    # v2.7 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_7_requires_missing_fields() raises:
    # v2.7 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_7_requires_on_object() raises:
    # v2.7 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_8_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.8 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.8 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_8_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.8 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_external_exact_same_definition_with_an_import() raises:
    # v2.8 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_8_external_no_object() raises:
    # v2.8 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_8_external_no_field_definition() raises:
    # v2.8 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_8_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.8 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_8_tag_exact_same_definition_with_import() raises:
    # v2.8 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_8_inaccessible_exact_same_definition_and_imported() raises:
    # v2.8 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_8_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.8 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_override_exact_same_definition_and_imported() raises:
    # v2.8 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_8_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.8 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.8 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_fields_of_string_type() raises:
    # v2.8 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_fields_of_different_type() raises:
    # v2.8 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_8_key_federation_fieldset_should_be_accepted() raises:
    # v2.8 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.8 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_missing_default_value_for_resolvable() raises:
    # v2.8 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_8_key_missing_resolvable() raises:
    # v2.8 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_missing_fields() raises:
    # v2.8 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_8_key_missing_repeatable() raises:
    # v2.8 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_not_on_interface() raises:
    # v2.8 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_not_on_object() raises:
    # v2.8 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_key_on_field() raises:
    # v2.8 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_8_key_fed_v1_uses_fieldset() raises:
    # v2.8 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_8_requires_should_be_ignored_if_not_imported() raises:
    # v2.8 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_requires_exact_definition() raises:
    # v2.8 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_requires_fields_of_string_type() raises:
    # v2.8 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_requires_fields_of_different_type() raises:
    # v2.8 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_8_requires_missing_fields() raises:
    # v2.8 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_8_requires_on_object() raises:
    # v2.8 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_9_extends_different_location_should_be_ignored_if_not_imported() raises:
    # v2.9 > @extends > different location should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_extends_different_location_should_be_ignored_if_imported_but_not_used() raises:
    # v2.9 > @extends > different location should be ignored if imported but not used
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ntype User @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "profiles",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\", \"@extends\"])\n\ndirective @extends on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  profile: Profile\n}\n\ntype Profile {\n  name: String!\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [profiles] Invalid definition for directive \"@extends\": \"@extends\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD_DEFINITION",
            "[INVALID_GRAPHQL] [profiles] There can be only one directive named \"@extends\".",
        ],
    )


def test_v2_9_external_exact_same_definition_without_an_import_should_be_ignored() raises:
    # v2.9 > @external > exact same definition without an import should be ignored
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_external_exact_same_definition_with_an_import() raises:
    # v2.9 > @external > exact same definition with an import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT | FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_9_external_no_object() raises:
    # v2.9 > @external > no OBJECT
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ndirective @external on FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @external\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_9_external_no_field_definition() raises:
    # v2.9 > @external > no FIELD_DEFINITION
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ndirective @external on OBJECT\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") @external {\n  id: ID!\n  name: String!\n}",
            ),
        ],
        [
            "[EXTERNAL_UNUSED] [users] Field \"User.name\" is marked @external but is not used in any federation directive (@key, @provides, @requires) or to satisfy an interface; the field declaration has no use and should be removed (or the field should not be @external).",
        ],
    )


def test_v2_9_tag_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.9 > @tag > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_9_tag_exact_same_definition_with_import() raises:
    # v2.9 > @tag > exact same definition with import
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\", \"@tag\"])\n\ndirective @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external @tag(name: \"public\")\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @tag(name: \"public\") to external field \"User.internalId\"",
        ],
    )


def test_v2_9_inaccessible_exact_same_definition_and_imported() raises:
    # v2.9 > @inaccessible > exact same definition and imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@inaccessible\", \"@external\"])\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
            "[MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL] [users] Cannot apply merged directive @inaccessible to external field \"User.internalId\"",
        ],
    )


def test_v2_9_inaccessible_exact_same_definition_should_be_ignored_when_not_imported() raises:
    # v2.9 > @inaccessible > exact same definition should be ignored when not imported
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@requires\", \"@provides\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible @external\n  profile: Profile @requires(fields: \"internalId\")\n}\n\ntype Profile {\n  name: String\n}",
            ),
            sg(
                "ext",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@external\"])\n\ndirective @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION\n\ntype Query {\n  users: [User]\n}\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  internalId: ID! @inaccessible\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_override_exact_same_definition_and_imported() raises:
    # v2.9 > @override > exact same definition and imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@override\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
            "[OVERRIDE_FROM_SELF_ERROR] [billing] Source and destination subgraphs \"billing\" are the same for overridden field \"Bill.amount\"",
        ],
    )


def test_v2_9_override_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.9 > @override > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "billing",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"])\n\ndirective @override(from: String!) on FIELD_DEFINITION\n\ntype Query {\n  bills: [Bill]\n}\n\ntype Bill @key(fields: \"id\") {\n  id: ID!\n  amount: Int! @override(from: \"billing\")\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_exact_same_definition_should_be_ignored_if_not_imported() raises:
    # v2.9 > @key > exact same definition should be ignored if not imported
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@external\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"THERE IS NO FIELD NAMED LIKE THIS\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_fields_of_string_type() raises:
    # v2.9 > @key > fields of String type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: String!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_fields_of_different_type() raises:
    # v2.9 > @key > fields of different type
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: [String!]!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@external\", \"@key\"]) {\n  query: Query\n}\n\ndirective @key(fields: Str!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar Str\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_9_key_federation_fieldset_should_be_accepted() raises:
    # v2.9 > @key > federation__FieldSet should be accepted
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/link/v1.0\") {\n  query: Query\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\", \"@provides\"])\n\ndirective @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\nscalar federation__FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_fed_v1_fields_of_string_type_should_be_accepted() raises:
    # v2.9 > @key > Fed v1: fields of [String!]! type should be accepted
    check(
        [
            sg(
                "users",
                "directive @key(fields: [String!]!) on OBJECT\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_missing_default_value_for_resolvable() raises:
    # v2.9 > @key > missing default value for resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@external\", \"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"resolvable\" should have default value true but found default value null",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_9_key_missing_resolvable() raises:
    # v2.9 > @key > missing resolvable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_missing_fields() raises:
    # v2.9 > @key > missing fields
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(field: FieldSet!) repeatable on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(field: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_9_key_missing_repeatable() raises:
    # v2.9 > @key > missing repeatable
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) on OBJECT | INTERFACE\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_not_on_interface() raises:
    # v2.9 > @key > not on INTERFACE
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT\n\nscalar FieldSet\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_not_on_object() raises:
    # v2.9 > @key > not on OBJECT
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on INTERFACE\n\nscalar FieldSet\n\ntype Query {\n  users: [String]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_key_on_field() raises:
    # v2.9 > @key > on FIELD
    check(
        [
            sg(
                "users",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"FieldSet\"]) {\n  query: Query\n}\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on FIELD\n\nscalar FieldSet\n\ntype User {\n  id: ID! @key(fields: \"id\")\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": \"@key\" should have locations OBJECT, INTERFACE, but found (non-subset) FIELD",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
            "[INVALID_GRAPHQL] [users] Directive \"@key\" may not be used on FIELD_DEFINITION.",
        ],
    )


def test_v2_9_key_fed_v1_uses_fieldset() raises:
    # v2.9 > @key > fed v1: uses FieldSet
    check(
        [
            sg(
                "users",
                "scalar FieldSet\n\ndirective @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String\n}\n\ntype Query {\n  users: [User]\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [users] Invalid definition for directive \"@key\": argument \"fields\" should have type \"_FieldSet!\" but found type \"FieldSet!\"",
            "[INVALID_GRAPHQL] [users] There can be only one directive named \"@key\".",
        ],
    )


def test_v2_9_requires_should_be_ignored_if_not_imported() raises:
    # v2.9 > @requires > should be ignored if not imported
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"IT DOES NOT EXIST!!!!! \")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_requires_exact_definition() raises:
    # v2.9 > @requires > exact definition
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\", \"FieldSet\", \"@requires\"])\n\ndirective @requires(fields: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_requires_fields_of_string_type() raises:
    # v2.9 > @requires > fields of String type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: String!) on FIELD_DEFINITION\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_requires_fields_of_different_type() raises:
    # v2.9 > @requires > fields of different type
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(fields: Str!) on FIELD_DEFINITION\n\nscalar Str\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": argument \"fields\" should have type \"FieldSet!\" but found type \"Str!\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_9_requires_missing_fields() raises:
    # v2.9 > @requires > missing fields
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\"])\n\ndirective @requires(field: FieldSet!) on FIELD_DEFINITION\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(field: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": missing required argument \"fields\"",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
        ],
    )


def test_v2_9_requires_on_object() raises:
    # v2.9 > @requires > on OBJECT
    check(
        [
            sg(
                "users",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT\n\ntype User @key(fields: \"email\") {\n  email: ID! @tag(name: \"test-from-users\")\n  name: String\n  totalProductsCreated: Int\n}",
            ),
            sg(
                "pandas",
                "directive @tag(name: String!) repeatable on FIELD_DEFINITION\n\ntype Query {\n  allPandas: [Panda]\n  panda(name: ID!): Panda\n}\n\ntype Panda {\n  name: ID!\n  favoriteFood: String @tag(name: \"nom-nom-nom\")\n}",
            ),
            sg(
                "products",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@shareable\", \"@tag\", \"@inaccessible\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/myDirective/v1.0\", import: [\"@myDirective\", {name: \"@anotherDirective\", as: \"@hello\"}]) @composeDirective(name: \"@myDirective\") @composeDirective(name: \"@hello\")\n\ndirective @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @hello on FIELD_DEFINITION\n\ntype Query {\n  allProducts: [ProductItf]\n  product(id: ID!): ProductItf\n}\n\ninterface ProductItf implements SkuItf {\n  id: ID!\n  sku: String\n  name: String\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String @inaccessible\n  oldField: String @deprecated(reason: \"refactored out\")\n}\n\ninterface SkuItf {\n  sku: String\n}\n\ntype Product implements ProductItf & SkuItf @key(fields: \"id\") @key(fields: \"sku package\") @key(fields: \"sku variation { id }\") {\n  id: ID! @tag(name: \"hi-from-products\")\n  sku: String\n  name: String @hello\n  package: String\n  variation: ProductVariation\n  dimensions: ProductDimension\n  createdBy: User\n  hidden: String\n  reviewsScore: Float!\n  oldField: String\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n}\n\ntype ProductVariation {\n  id: ID!\n  name: String\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype User @key(fields: \"email\") {\n  email: ID!\n  totalProductsCreated: Int @shareable\n}",
            ),
            sg(
                "reviews",
                "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@override\", \"@shareable\"]) {\n  query: Query\n}\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float! @shareable @override(from: \"products\")\n  reviews: [Review!]!\n}\n\ninterface ProductItf {\n  id: ID!\n  reviewsCount: Int!\n  reviewsScore: Float!\n  reviews: [Review!]!\n}\n\ntype Query {\n  review(id: Int!): Review\n}\n\ntype Review {\n  id: Int!\n  body: String!\n}",
            ),
            sg(
                "inventory",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@shareable\", \"@external\", \"@requires\", \"FieldSet\"])\n\ndirective @requires(fields: FieldSet!) on OBJECT\n\nscalar FieldSet\n\ntype Product implements ProductItf @key(fields: \"id\") {\n  id: ID!\n  dimensions: ProductDimension @external\n  delivery(zip: String): DeliveryEstimates @requires(fields: \"dimensions { size weight }\")\n}\n\ntype ProductDimension @shareable {\n  size: String\n  weight: Float\n}\n\ntype DeliveryEstimates {\n  estimatedDelivery: String\n  fastestDelivery: String\n}\n\ninterface ProductItf {\n  id: ID!\n  dimensions: ProductDimension\n  delivery(zip: String): DeliveryEstimates\n}\n\nenum ShippingClass {\n  STANDARD\n  EXPRESS\n  OVERNIGHT\n}",
            ),
        ],
        [
            "[DIRECTIVE_DEFINITION_INVALID] [inventory] Invalid definition for directive \"@requires\": \"@requires\" should have locations FIELD_DEFINITION, but found (non-subset) OBJECT",
            "[INVALID_GRAPHQL] [inventory] There can be only one directive named \"@requires\".",
            "[INVALID_GRAPHQL] [inventory] Directive \"@requires\" may not be used on FIELD_DEFINITION.",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
