# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.build_client_schema`, ported from graphql-js 16.14.2
`src/utilities/__tests__/buildClientSchema-test.ts`.
"""

from std.testing import TestSuite, assert_equal
from gql_json.parser import parse as parse_json
from gql_json.writer import stringify
from gql_schema.build import BuildOptions, build_schema
from gql_schema.build_client_schema import build_client_schema
from gql_schema.definition import Schema
from gql_schema.introspection import introspection_from_schema
from gql_schema.print import print_schema


def check_cycle(sdl: String, expected: String) raises:
    var options = BuildOptions()
    options.assume_valid = True
    var server = build_schema(sdl, options)
    var initial = introspection_from_schema(server, assume_valid=True)
    var client: Schema
    try:
        client = build_client_schema(initial, initial.root, assume_valid=True)
    except e:
        assert_equal("ERROR: " + String(e), expected)
        return
    assert_equal(print_schema(client), expected)
    var second = introspection_from_schema(client, assume_valid=True)
    assert_equal(
        stringify(second, second.root), stringify(initial, initial.root)
    )


def check_json(json: String, expected: String) raises:
    var document = parse_json(json)
    var printed: String
    try:
        printed = print_schema(build_client_schema(document, document.root))
    except e:
        printed = "ERROR: " + String(e)
    assert_equal(printed, expected)


def test_builds_a_simple_schema() raises:
    check_cycle(
        '''"""Simple schema"""
schema {
  query: Simple
}

"""This is a simple type"""
type Simple {
  """This is a string field"""
  string: String
}''',
        (
            '"""Simple schema"""\nschema {\n  query: Simple\n}\n\n"""This is a '
            'simple type"""\ntype Simple {\n  """This is a string field"""\n  s'
            "tring: String\n}"
        ),
    )


def test_builds_a_schema_without_the_query_type() raises:
    check_json(
        (
            '{"__schema":{"description":null,"mutationType":null,"subscriptionT'
            'ype":null,"types":[{"kind":"OBJECT","name":"Query","description":n'
            'ull,"specifiedByURL":null,"isOneOf":null,"fields":[{"name":"foo","'
            'description":null,"args":[],"type":{"kind":"SCALAR","name":"String'
            '","ofType":null},"isDeprecated":false,"deprecationReason":null}],"'
            'inputFields":null,"interfaces":[],"enumValues":null,"possibleTypes'
            '":null},{"kind":"SCALAR","name":"String","description":null,"speci'
            'fiedByURL":null,"isOneOf":null,"fields":null,"inputFields":null,"i'
            'nterfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"S'
            'CALAR","name":"Boolean","description":null,"specifiedByURL":null,"'
            'isOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"'
            'enumValues":null,"possibleTypes":null}],"directives":[]}}'
        ),
        "type Query {\n  foo: String\n}",
    )


def test_builds_a_simple_schema_with_all_operation_types() raises:
    check_cycle(
        '''schema {
  query: QueryType
  mutation: MutationType
  subscription: SubscriptionType
}

"""This is a simple mutation type"""
type MutationType {
  """Set the string field"""
  string: String
}

"""This is a simple query type"""
type QueryType {
  """This is a string field"""
  string: String
}

"""This is a simple subscription type"""
type SubscriptionType {
  """This is a string field"""
  string: String
}''',
        (
            "schema {\n  query: QueryType\n  mutation: MutationType\n "
            ' subscription: SubscriptionType\n}\n\n"""This is a simple mutation'
            ' type"""\ntype MutationType {\n  """Set the string field"""\n '
            ' string: String\n}\n\n"""This is a simple query type"""\ntype'
            ' QueryType {\n  """This is a string field"""\n  string:'
            ' String\n}\n\n"""This is a simple subscription type"""\ntype'
            ' SubscriptionType {\n  """This is a string field"""\n  string:'
            " String\n}"
        ),
    )


def test_uses_built_in_scalars_when_possible() raises:
    check_cycle(
        """scalar CustomScalar

type Query {
  int: Int
  float: Float
  string: String
  boolean: Boolean
  id: ID
  custom: CustomScalar
}""",
        (
            "scalar CustomScalar\n\ntype Query {\n  int: Int\n  float: Float\n "
            " string: String\n  boolean: Boolean\n  id: ID\n  custom: CustomSca"
            "lar\n}"
        ),
    )


def test_builds_a_schema_with_an_interface_hierarchy() raises:
    check_cycle(
        '''type Dog implements Friendly & Named {
  bestFriend: Friendly
  name: String
}

interface Friendly implements Named {
  """The best friend of this friendly thing"""
  bestFriend: Friendly
  name: String
}

type Human implements Friendly & Named {
  bestFriend: Friendly
  name: String
}

interface Named {
  name: String
}

type Query {
  friendly: Friendly
}''',
        (
            "type Dog implements Friendly & Named {\n  bestFriend: Friendly\n  "
            'name: String\n}\n\ninterface Friendly implements Named {\n  """The'
            ' best friend of this friendly thing"""\n  bestFriend: Friendly\n  '
            "name: String\n}\n\ntype Human implements Friendly & Named {\n  bes"
            "tFriend: Friendly\n  name: String\n}\n\ninterface Named {\n  name:"
            " String\n}\n\ntype Query {\n  friendly: Friendly\n}"
        ),
    )


def test_builds_a_schema_with_a_union() raises:
    check_cycle(
        """type Dog {
  bestFriend: Friendly
}

union Friendly = Dog | Human

type Human {
  bestFriend: Friendly
}

type Query {
  friendly: Friendly
}""",
        (
            "type Dog {\n  bestFriend: Friendly\n}\n\nunion Friendly = Dog | Hu"
            "man\n\ntype Human {\n  bestFriend: Friendly\n}\n\ntype Query {\n  "
            "friendly: Friendly\n}"
        ),
    )


def test_builds_a_schema_with_complex_field_values() raises:
    check_cycle(
        """type Query {
  string: String
  listOfString: [String]
  nonNullString: String!
  nonNullListOfString: [String]!
  nonNullListOfNonNullString: [String!]!
}""",
        (
            "type Query {\n  string: String\n  listOfString: [String]\n  nonNul"
            "lString: String!\n  nonNullListOfString: [String]!\n  nonNullListO"
            "fNonNullString: [String!]!\n}"
        ),
    )


def test_builds_a_schema_with_custom_directives_and_deprecation() raises:
    check_cycle(
        '''"""This is a custom directive"""
directive @customDirective repeatable on FIELD | QUERY

directive @someDirective(
  """This is a shiny new argument"""
  shinyArg: SomeInputObject

  """This was our design mistake :("""
  oldArg: String @deprecated(reason: "Use shinyArg")
) on QUERY

enum Color {
  """So rosy"""
  RED
  MAUVE @deprecated(reason: "No longer in fashion")
}

input SomeInputObject @oneOf {
  """Nothing special about it, just deprecated for some unknown reason"""
  oldField: String @deprecated(reason: "Don't use it, use newField instead!")

  """Same field but with a new name"""
  newField: String
}

scalar Foo @specifiedBy(url: "https://example.com/foo_spec")

type Query {
  shinyString: Foo
  deprecatedString: String @deprecated(reason: "Use shinyString")
  color: Color
  someField(
    shinyArg: SomeInputObject
    oldArg: String = "default" @deprecated(reason: "Use shinyArg")
  ): String
}''',
        (
            '"""This is a custom directive"""\ndirective @customDirective repea'
            "table on FIELD | QUERY\n\ndirective @someDirective(\n"
            '  """This is a shiny new argument"""\n  shinyArg: SomeInputObject'
            '\n\n  """This was our design mistake :("""\n  oldArg: String'
            ' @deprecated(reason: "Use shinyArg")\n) on QUERY\n\nenum Color {\n'
            '  """So rosy"""\n  RED\n  MAUVE @deprecated(reason: "No longer in'
            ' fashion")\n}\n\ninput SomeInputObject @oneOf {\n  """Nothing'
            ' special about it, just deprecated for some unknown reason"""\n '
            " oldField: String @deprecated(reason: \"Don't use it, use newField"
            ' instead!")\n\n  """Same field but with a new name"""\n  newField:'
            " String\n}\n\nscalar Foo @specifiedBy(url:"
            ' "https://example.com/foo_spec")\n\ntype Query {\n  shinyString:'
            ' Foo\n  deprecatedString: String @deprecated(reason: "Use'
            ' shinyString")\n  color: Color\n  someField(shinyArg:'
            ' SomeInputObject, oldArg: String = "default"'
            ' @deprecated(reason: "Use shinyArg")): String\n}'
        ),
    )


def test_builds_a_schema_with_deprecated_directives() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"string","description":null,'
            '"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},"'
            'isDeprecated":false,"deprecationReason":null}],"inputFields":null,'
            '"interfaces":[],"enumValues":null,"possibleTypes":null},{"kind":"S'
            'CALAR","name":"String","description":null,"specifiedByURL":null,"i'
            'sOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"e'
            'numValues":null,"possibleTypes":null},{"kind":"SCALAR","name":"Boo'
            'lean","description":null,"specifiedByURL":null,"isOneOf":null,"fie'
            'lds":null,"inputFields":null,"interfaces":null,"enumValues":null,"'
            'possibleTypes":null}],"directives":[{"name":"someDirective","descr'
            'iption":null,"isRepeatable":false,"isDeprecated":true,"deprecation'
            'Reason":"Use another directive","locations":["QUERY"],"args":[]}]}'
            "}"
        ),
        (
            'directive @someDirective @deprecated(reason: "Use another directiv'
            'e") on QUERY\n\ntype Query {\n  string: String\n}'
        ),
    )


def test_builds_a_schema_without_directives() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"string","description":null,'
            '"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},"'
            'isDeprecated":false,"deprecationReason":null}],"inputFields":null,'
            '"interfaces":[],"enumValues":null,"possibleTypes":null},{"kind":"S'
            'CALAR","name":"String","description":null,"specifiedByURL":null,"i'
            'sOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"e'
            'numValues":null,"possibleTypes":null},{"kind":"SCALAR","name":"Boo'
            'lean","description":null,"specifiedByURL":null,"isOneOf":null,"fie'
            'lds":null,"inputFields":null,"interfaces":null,"enumValues":null,"'
            'possibleTypes":null}]}}'
        ),
        "type Query {\n  string: String\n}",
    )


def test_can_build_invalid_schema() raises:
    check_cycle(
        """type Query""",
        "type Query",
    )


def test_throws_on_invalid_introspection_cases() raises:
    check_json(
        "null",
        (
            "ERROR: Invalid or incomplete introspection result. Ensure that you"
            ' are passing "data" property of introspection response and no "err'
            'ors" was returned alongside: null.'
        ),
    )
    check_json(
        "{}",
        (
            "ERROR: Invalid or incomplete introspection result. Ensure that you"
            ' are passing "data" property of introspection response and no "err'
            'ors" was returned alongside: {}.'
        ),
    )
    check_json(
        '{"__schema":{"queryType":null,"directives":[]}}',
        "ERROR: list is not iterable",
    )
    check_json(
        (
            '{"__schema":{"queryType":null,"types":[{"kind":"SCALAR","name":"St'
            'ring","description":null,"specifiedByURL":null}]}}'
        ),
        "",
    )
    check_json(
        (
            '{"__schema": {"queryType": null, "types": [], "directives":'
            ' [{"name": "x", "description": null, "isRepeatable": false,'
            ' "locations": [], "args": []}]}}'
        ),
        "ERROR: A directive must have at least one location: @x.",
    )
    check_json(
        (
            '{"__schema": {"queryType": null, "types": [{"kind": 5, "name":'
            ' "X"}]}}'
        ),
        (
            "ERROR: Invalid or incomplete introspection result. Ensure that a"
            " full introspection query is used in order to build a client"
            ' schema: { kind: 5, name: "X" }.'
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":null,"directives":[],"types":[{"kind":"ENUM",'
            '"name":"E","description":null,"enumValues":[]},{"kind":"INPUT_OBJECT",'
            '"name":"I","description":null,"inputFields":[],"isOneOf":false}]}}'
        ),
        "enum E\n\ninput I",
    )


def _ref(name: String) -> String:
    return (
        '{"__schema": {"queryType": null, "types": [{"kind": "OBJECT", "name":'
        ' "Query", "description": null, "interfaces": [], "fields": [{"name":'
        ' "f", "description": null, "args": [], "type": {"kind": "OBJECT",'
        ' "name": '
        + name
        + '}, "isDeprecated": false, "deprecationReason": null}]}],'
        ' "directives": []}}'
    )


def test_type_reference_and_missing_fields_errors() raises:
    check_json(
        _ref("5"),
        (
            "ERROR: Invalid or incomplete schema, unknown type: 5. Ensure that "
            "a full introspection query is used in order to build a client sche"
            "ma."
        ),
    )
    check_json(
        _ref("true"),
        (
            "ERROR: Invalid or incomplete schema, unknown type: true. Ensure"
            " that a full introspection query is used in order to build a"
            " client schema."
        ),
    )
    check_json(
        _ref("0"),
        'ERROR: Unknown type reference: { kind: "OBJECT", name: 0 }.',
    )
    check_json(
        _ref("false"),
        'ERROR: Unknown type reference: { kind: "OBJECT", name: false }.',
    )
    check_json(
        _ref('""'),
        'ERROR: Unknown type reference: { kind: "OBJECT", name: "" }.',
    )
    check_json(
        (
            '{"__schema":{"queryType":{"kind":"OBJECT"},"types":[{"kind":"SCALA'
            'R","name":"String","description":null,"specifiedByURL":null}]}}'
        ),
        'ERROR: Unknown type reference: { kind: "OBJECT" }.',
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String","description":null,"specifiedByURL":null},{"kind'
            '":"OBJECT","name":"Query","description":null,"interfaces":[],"fiel'
            'ds":[{"name":"f","description":null,"args":[],"type":{"kind":"NON_'
            'NULL","ofType":{"kind":"NON_NULL","ofType":{"kind":"SCALAR","name"'
            ':"String"}}},"isDeprecated":false,"deprecationReason":null}]}],"di'
            'rectives":[]}}'
        ),
        "ERROR: Expected String! to be a GraphQL nullable type.",
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String","description":null,"specifiedByURL":null},{"kind'
            '":"OBJECT","name":"Query","description":null,"interfaces":[],"fiel'
            'ds":[{"name":"f","description":null,"args":[{"name":"a","descripti'
            'on":null,"type":{"kind":"SCALAR","name":"String"},"defaultValue":"'
            '{","isDeprecated":false,"deprecationReason":null}],"type":{"kind":'
            '"SCALAR","name":"String"},"isDeprecated":false,"deprecationReason"'
            ':null}]}],"directives":[]}}'
        ),
        "ERROR: Syntax Error: Expected Name, found <EOF>.",
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String","description":null,"specifiedByURL":null},{"kind'
            '":"OBJECT","name":"Query","description":null,"interfaces":[],"fiel'
            'ds":[{"name":"f","description":null,"args":[{"name":"a","descripti'
            'on":null,"type":{"kind":"SCALAR","name":"String"},"defaultValue":"'
            '$x","isDeprecated":false,"deprecationReason":null}],"type":{"kind"'
            ':"SCALAR","name":"String"},"isDeprecated":false,"deprecationReason'
            '":null}]}],"directives":[]}}'
        ),
        "type Query {\n  f(a: String): String\n}",
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String","description":null,"specifiedByURL":null},{"kind'
            '":"OBJECT","name":"Query","description":null,"interfaces":null,"fi'
            'elds":[{"name":"f","description":null,"args":[],"type":{"kind":"SC'
            'ALAR","name":"String"},"isDeprecated":false,"deprecationReason":nu'
            'll}]}],"directives":[]}}'
        ),
        (
            'ERROR: Introspection result missing interfaces: { kind: "OBJECT", '
            'name: "Query", description: null, interfaces: null, fields: [[Obje'
            "ct]] }."
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String","description":null,"specifiedByURL":null},{"kind'
            '":"INTERFACE","name":"I","description":null,"interfaces":null,"fie'
            'lds":[{"name":"f","description":null,"args":[],"type":{"kind":"SCA'
            'LAR","name":"String"},"isDeprecated":false,"deprecationReason":nul'
            'l}]},{"kind":"OBJECT","name":"Query","description":null,"interface'
            's":[],"fields":[{"name":"f","description":null,"args":[],"type":{"'
            'kind":"SCALAR","name":"String"},"isDeprecated":false,"deprecationR'
            'eason":null}]}],"directives":[]}}'
        ),
        "interface I {\n  f: String\n}\n\ntype Query {\n  f: String\n}",
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"OBJECT'
            '","name":"Query","description":null,"interfaces":[]}],"directives"'
            ":[]}}"
        ),
        (
            'ERROR: Introspection result missing fields: { kind: "OBJECT", name'
            ': "Query", description: null, interfaces: [] }.'
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String"},{"kind":"OBJECT","name":"Query","interfaces":[]'
            ',"fields":[{"name":"f","type":{"kind":"SCALAR","name":"String"}}]}'
            '],"directives":[]}}'
        ),
        (
            'ERROR: Introspection result missing field args: { name: "f", type:'
            ' { kind: "SCALAR", name: "String" } }.'
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String"},{"kind":"UNION","name":"U","possibleTypes":[]},'
            '{"kind":"OBJECT","name":"Query","interfaces":[],"fields":[{"name":'
            '"f","args":[{"name":"a","type":{"kind":"UNION","name":"U"}}],"type'
            '":{"kind":"SCALAR","name":"String"}}]}],"directives":[]}}'
        ),
        (
            "ERROR: Introspection must provide input type for arguments, but re"
            "ceived: U."
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"INPUT_'
            'OBJECT","name":"I","inputFields":[]},{"kind":"OBJECT","name":"Quer'
            'y","interfaces":[],"fields":[{"name":"f","args":[],"type":{"kind":'
            '"INPUT_OBJECT","name":"I"}}]}],"directives":[]}}'
        ),
        (
            "ERROR: Introspection must provide output type for fields, but rece"
            "ived: I."
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":null,"types":[{"kind":"UNION","name":"U"}'
            '],"directives":[]}}'
        ),
        (
            'ERROR: Introspection result missing possibleTypes: { kind: "UNION"'
            ', name: "U" }.'
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":null,"types":[{"kind":"ENUM","name":"E"}]'
            ',"directives":[]}}'
        ),
        (
            'ERROR: Introspection result missing enumValues: { kind: "ENUM", na'
            'me: "E" }.'
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":null,"types":[{"kind":"INPUT_OBJECT","nam'
            'e":"I"}],"directives":[]}}'
        ),
        (
            'ERROR: Introspection result missing inputFields: { kind: "INPUT_OB'
            'JECT", name: "I" }.'
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":null,"types":[],"directives":[{"name":"d"'
            ',"args":[]}]}}'
        ),
        (
            'ERROR: Introspection result missing directive locations: { name: "'
            'd", args: [] }.'
        ),
    )
    check_json(
        (
            '{"__schema":{"queryType":null,"types":[],"directives":[{"name":"d"'
            ',"locations":["QUERY"]}]}}'
        ),
        (
            'ERROR: Introspection result missing directive args: { name: "d", l'
            'ocations: ["QUERY"] }.'
        ),
    )
    check_json(
        '{"__schema":{"queryType":null,"types":[{"kind":"SCALAR"}]}}',
        (
            "ERROR: Invalid or incomplete introspection result. Ensure that a f"
            "ull introspection query is used in order to build a client schema:"
            ' { kind: "SCALAR" }.'
        ),
    )
    check_cycle(
        "type Query {\n  foo: [[[[[[[[[[String]]]]]]]]]]\n}",
        "ERROR: Decorated type deeper than introspection query.",
    )
    check_cycle(
        (
            "type Query {\n  foo: Foo\n}\n\ntype Foo implements Foo {\n  foo:"
            " String\n}"
        ),
        "ERROR: Expected Foo to be a GraphQL Interface type.",
    )
    check_cycle(
        "type Query {\n  foo: Foo\n}\n\nunion Foo = Foo",
        "ERROR: Expected Foo to be a GraphQL Object type.",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
