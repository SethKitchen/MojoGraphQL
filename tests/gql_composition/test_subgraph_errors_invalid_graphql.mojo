# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/INVALID_GRAPHQL.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.0 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_0_invalid_graphql_provides_without_fields() raises:
    # v2.0 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_0_invalid_graphql_unknown_type() raises:
    # v2.0 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_0_invalid_graphql_default_value() raises:
    # v2.0 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_0_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.0 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@composeDirective".'
            ),
        ],
    )


def test_v2_0_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.0 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@composeDirective".'
            ),
        ],
    )


def test_v2_0_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.0 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@composeDirective".'
            ),
        ],
    )


def test_v2_0_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.0 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.0 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.0",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_0_interface_field_object_field_subtype() raises:
    # v2.0 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_1_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.1 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_1_invalid_graphql_provides_without_fields() raises:
    # v2.1 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_1_invalid_graphql_unknown_type() raises:
    # v2.1 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_1_invalid_graphql_default_value() raises:
    # v2.1 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_1_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.1 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_1_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.1 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_1_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.1 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_1_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.1 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.1 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_1_interface_field_object_field_subtype() raises:
    # v2.1 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_2_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.2 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_2_invalid_graphql_provides_without_fields() raises:
    # v2.2 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_2_invalid_graphql_unknown_type() raises:
    # v2.2 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_2_invalid_graphql_default_value() raises:
    # v2.2 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_2_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.2 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_2_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.2 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_2_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.2 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_2_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.2 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.2 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.2",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_2_interface_field_object_field_subtype() raises:
    # v2.2 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_3_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.3 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_3_invalid_graphql_provides_without_fields() raises:
    # v2.3 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_3_invalid_graphql_unknown_type() raises:
    # v2.3 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_3_invalid_graphql_default_value() raises:
    # v2.3 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_3_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.3 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_3_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.3 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_3_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.3 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_3_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.3 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.3 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_3_interface_field_object_field_subtype() raises:
    # v2.3 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_4_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.4 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_4_invalid_graphql_provides_without_fields() raises:
    # v2.4 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_4_invalid_graphql_unknown_type() raises:
    # v2.4 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_4_invalid_graphql_default_value() raises:
    # v2.4 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_4_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.4 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_4_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.4 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_4_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.4 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_4_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.4 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.4 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.4",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_4_interface_field_object_field_subtype() raises:
    # v2.4 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_5_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.5 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_5_invalid_graphql_provides_without_fields() raises:
    # v2.5 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_5_invalid_graphql_unknown_type() raises:
    # v2.5 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_5_invalid_graphql_default_value() raises:
    # v2.5 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_5_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.5 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_5_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.5 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_5_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.5 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_5_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.5 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.5 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.5",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_5_interface_field_object_field_subtype() raises:
    # v2.5 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_6_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.6 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_6_invalid_graphql_provides_without_fields() raises:
    # v2.6 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_6_invalid_graphql_unknown_type() raises:
    # v2.6 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_6_invalid_graphql_default_value() raises:
    # v2.6 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_6_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.6 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_6_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.6 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_6_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.6 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_6_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.6 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.6 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.6",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_6_interface_field_object_field_subtype() raises:
    # v2.6 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_7_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.7 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_7_invalid_graphql_provides_without_fields() raises:
    # v2.7 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_7_invalid_graphql_unknown_type() raises:
    # v2.7 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_7_invalid_graphql_default_value() raises:
    # v2.7 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_7_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.7 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_7_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.7 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_7_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.7 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_7_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.7 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.7 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.7",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_7_interface_field_object_field_subtype() raises:
    # v2.7 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_8_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.8 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_8_invalid_graphql_provides_without_fields() raises:
    # v2.8 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_8_invalid_graphql_unknown_type() raises:
    # v2.8 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_8_invalid_graphql_default_value() raises:
    # v2.8 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_8_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.8 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_8_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.8 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_8_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.8 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_8_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.8 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.8 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.8",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_8_interface_field_object_field_subtype() raises:
    # v2.8 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def test_v2_9_invalid_graphql_invalid_value_for_fields_input_object() raises:
    # v2.9 > INVALID_GRAPHQL - invalid value for fields (input object)
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @key(fields: FieldSet!,'
                    " resolvable: Boolean = true) repeatable on OBJECT |"
                    " INTERFACE\n\ninput FieldSet {\n  fields:"
                    ' [String!]!\n}\n\ntype User @key(fields: "id name ") {\n '
                    " id: ID!\n  name: String\n}\n\nextend type Query {\n "
                    " user(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[TYPE_DEFINITION_INVALID] [users] Invalid definition for type"
                " FieldSet: FieldSet should be a ScalarType but is defined as a"
                " InputObjectType"
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@key(fields:)" of'
                ' type "FieldSet!" in application of "@key" to "User".'
            ),
        ],
    )


def test_v2_9_invalid_graphql_provides_without_fields() raises:
    # v2.9 > INVALID_GRAPHQL - @provides without fields
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@provides"])\n\ntype Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [billing] Directive "@provides" argument'
                ' "fields" of type "FieldSet!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_v2_9_invalid_graphql_unknown_type() raises:
    # v2.9 > INVALID_GRAPHQL - unknown type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User]\n}\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID\n  profile:'
                    " Profile\n}"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [users] Unknown type Profile",
        ],
    )


def test_v2_9_invalid_graphql_default_value() raises:
    # v2.9 > INVALID_GRAPHQL - default value
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users(role: Role ='
                    ' "Oopsie"): [User]\n  allUsers(role: Role = OOPSIE):'
                    " [User]\n  usersByIDs(ids: [ID!]! = []): [User]\n "
                    " usersByID(id: ID! = NULL): [User]\n  usersByID2(id: ID! ="
                    " null): [User]\n  filterUsers(filter: Filter = {role:"
                    ' "Oopsie"}): [User]\n}\n\ninput Filter {\n  role: Role ='
                    " OOPSIE\n}\n\nenum Role {\n  ADMIN\n  USER\n}\n\ntype User"
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got:"
                ' "Oopsie") provided for argument Query.users(role:) of type'
                " Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for argument Query.allUsers(role:) of type Role."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: NULL)"
                " provided for argument Query.usersByID(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: null)"
                " provided for argument Query.usersByID2(id:) of type ID!."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: {role:"
                ' "Oopsie"}) provided for argument Query.filterUsers(filter:)'
                " of type Filter."
            ),
            (
                "[INVALID_GRAPHQL] [users] Invalid default value (got: OOPSIE)"
                " provided for input field Filter.role of type Role."
            ),
        ],
    )


def test_v2_9_invalid_graphql_composedirective_gets_a_boolean_instead_of_string() raises:
    # v2.9 > INVALID_GRAPHQL - composeDirective gets a Boolean instead of String
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    " @composeDirective(name: true)\n\ndirective @hello(name:"
                    " String) on FIELD_DEFINITION\n\ntype Query {\n  words:"
                    " [String!]! @hello(name: true)\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [users] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(name:)" of'
                ' type "String" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_9_invalid_graphql_composed_directive_gets_an_int_instead_of_input_type() raises:
    # v2.9 > INVALID_GRAPHQL - composed directive gets an Int instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_9_invalid_graphql_composed_directive_gets_a_float_instead_of_input_type() raises:
    # v2.9 > INVALID_GRAPHQL - composed directive gets a Float instead of Input type
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: 123.4)\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [users] Invalid value for "@hello(person:)"'
                ' of type "Person" in application of "@hello" to "Query.words".'
            ),
        ],
    )


def test_v2_9_no_invalid_graphql_when_directive_gets_instead_of_string() raises:
    # v2.9 > No INVALID_GRAPHQL when directive gets [] instead of [STRING]
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable"])\n\ndirective @hello(names: [String]) on'
                    " FIELD_DEFINITION\n\ntype Query {\n  words: [String!]!"
                    " @shareable @hello(names: [])\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_directive_overwritten_specified_directive_like_deprecated_on_wrong_location() raises:
    # v2.9 > directive overwritten specified directive (like @deprecated) on wrong location
    check(
        [
            sg(
                "mono",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.9",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    ' @deprecated(reason: String = "No longer supported") on'
                    " FIELD_DEFINITION\n\ndirective @shareable repeatable on"
                    " OBJECT | FIELD_DEFINITION\n\ntype Query @shareable {\n "
                    " view(input: Input): View!\n}\n\ntype View @shareable {\n "
                    " user: String\n  post: String!\n}\n\ninput Input {\n "
                    ' input: String @deprecated(reason: "impossibru")\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [mono] Directive "@deprecated" may not be'
                " used on INPUT_FIELD_DEFINITION."
            ),
        ],
    )


def test_v2_9_interface_field_object_field_subtype() raises:
    # v2.9 > interface field -> object field subtype
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  a: Admin\n}\n\ntype Admin'
                    " implements Node {\n  id: ID\n}\n\ninterface Node {\n  id:"
                    " ID!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field Node.id expects type ID!"
                " but Admin.id of type ID is not a proper subtype."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
