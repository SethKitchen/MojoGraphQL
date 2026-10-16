# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/interface-object-composition.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_interface_object_composition_if_link_directive_is_not_present_on_all_subgraphs_c() raises:
    # interface object composition > if link directive is not present on all subgraphs, composition should fail
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  hello: String\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "type Query {\n  otherField: String\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [b] Unknown directive \"@interfaceObject\". If you meant the \"@interfaceObject\" federation 2 directive, note that this schema is a federation 1 schema. To be a federation 2 schema, it needs to @link to the federation specification v2.",
            "[INVALID_GRAPHQL] [b] Unknown directive \"@interfaceObject\".",
        ],
    )


def test_interface_object_composition_link_directive_should_have_url_pointing_to_federati() raises:
    # interface object composition > link directive should have url pointing to federation > 2.3 to enable @interfaceObject on all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  hello: MyInterface\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  otherField: MyInterface\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@interfaceObject\".",
        ],
    )


def test_interface_object_composition_external_requires_interfaceobject() raises:
    # interface object composition > @external + @requires + @interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\"])\n\ntype Query {\n  hello: MyInterface\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String @shareable\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\", \"@shareable\", \"@requires\", \"@external\"])\n\ntype MyInterface @key(fields: \"id\", resolvable: false) @interfaceObject {\n  id: ID!\n  newField: String @external\n  field: String @shareable @requires(fields: \"newField\")\n}",
            ),
        ],
        [
        ],
    )


def test_interface_object_composition_link_directive_does_not_have_to_import_interfaceobj() raises:
    # interface object composition > link directive does not have to import @interfaceObject in all subgraphs
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])\n\ntype Query {\n  hello: MyInterface\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  otherField: MyInterface\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
        ],
        [
        ],
    )


def test_interface_object_composition_target_interface_must_have_key_directive_on_subgrap() raises:
    # interface object composition > target interface must have @key directive on subgraph where it's defined
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  hello: MyInterface\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  otherField: MyInterface\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
        ],
        [
        ],
    )


def test_interface_object_composition_subgraph_where_interface_is_defined_must_have_all_e() raises:
    # interface object composition > subgraph where interface is defined must have all entity types which implement that interface defined 
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  hello: MyInterface\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  otherField: MyInterface\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}\n\ntype MyType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
        ],
        [
            "[INVALID_GRAPHQL] [b] Cannot implement non-interface type MyInterface (of type ObjectType)",
            "[INVALID_GRAPHQL] [b] Interface field MyInterface.newField expected but MyType does not provide it.",
        ],
    )


def test_interface_object_composition_interfaceobject_definition_at_least_one_other_subgr() raises:
    # interface object composition > @interfaceObject definition > at least one other subgraph must define an interface type with @key directive which has the same name as the object type with @interfaceObject > interface type is not present on any subgraph. Should fail
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  hello: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  otherField: MyInterface\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
        ],
        [
        ],
    )


def test_interface_object_composition_interfaceobject_definition_at_least_one_other_subgr_2() raises:
    # interface object composition > @interfaceObject definition > at least one other subgraph must define an interface type with @key directive which has the same name as the object type with @interfaceObject > interface type is present on other subgraph but doesn't have @key directive. Should fail
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  hello: MyInterface\n}\n\ninterface MyInterface {\n  id: ID!\n  field: String\n}\n\ntype SomeType implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  otherField: MyInterface\n}\n\ntype MyInterface @interfaceObject {\n  id: ID!\n  newField: String\n}",
            ),
        ],
        [
            "[INTERFACE_OBJECT_USAGE_ERROR] [b] The @interfaceObject directive can only be applied to entity types but type \"MyInterface\" has no @key in this subgraph.",
        ],
    )


def test_interface_object_composition_interfaceobject_definition_at_least_one_other_subgr_3() raises:
    # interface object composition > @interfaceObject definition > at least one other subgraph must define an interface type with @key directive which has the same name as the object type with @interfaceObject > interface type is present on other subgraph with @key directive. Should succeed and add fields from interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  hello: MyInterface\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype IimplementMyInterface implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  otherField: MyInterface\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  hello: Int\n}",
            ),
        ],
        [
        ],
    )


def test_interface_object_composition_interfaceobject_definition_at_least_one_other_subgr_4() raises:
    # interface object composition > @interfaceObject definition > at least one other subgraph must define an interface type with @key directive which has the same name as the object type with @interfaceObject > interface type is present on other subgraph with @key directive. Should succeed and add fields from a child of an interfaceObject
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@interfaceObject\"])\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  title: String!\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  reviews: [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}",
            ),
        ],
        [
        ],
    )


def test_interface_object_composition_interfaceobject_definition_fields_contribution_seve() raises:
    # interface object composition > @interfaceObject definition > fields contribution > several subgraphs contribute fields to the same interface through interfaceObject. Should succeed
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  hello: MyInterface\n}\n\ninterface MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}\n\ntype IimplementMyInterface implements MyInterface @key(fields: \"id\") {\n  id: ID!\n  field: String\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  otherField: MyInterface\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  hello: Int\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])\n\ntype Query {\n  someNewField: MyInterface\n}\n\ntype MyInterface @key(fields: \"id\") @interfaceObject {\n  id: ID!\n  hello2: Int\n}",
            ),
        ],
        [
        ],
    )


def test_interface_object_composition_satisfiability_with_interfaceobject() raises:
    # interface object composition > satisfiability with @interfaceObject
    check(
        [
            sg(
                "a",
                "type Query {\n  book: Book!\n}\n\ninterface Media @key(fields: \"id\") {\n  id: ID!\n}\n\ntype Book implements Media @key(fields: \"id\") {\n  id: ID!\n  isbn: String!\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])",
            ),
            sg(
                "b",
                "type Media @key(fields: \"id\") @interfaceObject {\n  id: ID!\n}\n\ntype Query {\n  topRatedMedia: [Media!]!\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@interfaceObject\"])",
            ),
            sg(
                "c",
                "type Query {\n  cBook: Book\n}\n\ntype Book @key(fields: \"id\") {\n  id: ID!\n}\n\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"])",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
