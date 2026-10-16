# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `build_client_schema`, ported from graphql-js 16.14.2
`src/utilities/__tests__/buildClientSchema-test.ts`.

Each upstream call of `buildClientSchema` is ported. When upstream builds
the introspection result with `introspectionFromSchema`, the Mojo test
builds it the same way from the SDL that graphql-js `printSchema` gives
for the server schema, and checks the upstream cycle: the client schema
prints as graphql-js prints it, and its introspection result is the
server's. Each other result is the JSON that upstream passes, without the
introspection types and the specified directives where graphql-js gives
the same outcome without them. The expected text is the `printSchema` of
graphql-js, or its error message.

The execution part of `can use client schema for limited execution` uses
a JavaScript root value, so only its build part is ported. In `builds a
schema without directives` the client schema has the specified
directives, as a `gql_schema` schema always does; its printed SDL is the
upstream text.
"""

from std.testing import TestSuite, assert_equal
from gql_execution.build_client_schema import build_client_schema
from gql_execution.introspection import introspection_from_schema
from gql_json.parser import parse as parse_json
from gql_json.writer import stringify
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import Schema
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


def test_uses_built_in_scalars_when_possible_2() raises:
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


def test_includes_standard_types_only_if_they_are_used() raises:
    check_cycle(
        """type Query {
  foo: String
}""",
        "type Query {\n  foo: String\n}",
    )


def test_builds_a_schema_with_a_recursive_type_reference() raises:
    check_cycle(
        """schema {
  query: Recur
}

type Recur {
  recur: Recur
}""",
        "schema {\n  query: Recur\n}\n\ntype Recur {\n  recur: Recur\n}",
    )


def test_builds_a_schema_with_a_circular_type_reference() raises:
    check_cycle(
        """type Dog {
  bestFriend: Human
}

type Human {
  bestFriend: Dog
}

type Query {
  dog: Dog
  human: Human
}""",
        (
            "type Dog {\n  bestFriend: Human\n}\n\ntype Human {\n  bestFriend: "
            "Dog\n}\n\ntype Query {\n  dog: Dog\n  human: Human\n}"
        ),
    )


def test_builds_a_schema_with_an_interface() raises:
    check_cycle(
        '''type Dog implements Friendly {
  bestFriend: Friendly
}

interface Friendly {
  """The best friend of this friendly thing"""
  bestFriend: Friendly
}

type Human implements Friendly {
  bestFriend: Friendly
}

type Query {
  friendly: Friendly
}''',
        (
            "type Dog implements Friendly {\n  bestFriend: Friendly\n}\n\ninter"
            'face Friendly {\n  """The best friend of this friendly thing"""\n '
            " bestFriend: Friendly\n}\n\ntype Human implements Friendly {\n  be"
            "stFriend: Friendly\n}\n\ntype Query {\n  friendly: Friendly\n}"
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


def test_builds_a_schema_with_an_implicit_interface() raises:
    check_cycle(
        '''type Dog implements Friendly {
  bestFriend: Friendly
}

interface Friendly {
  """The best friend of this friendly thing"""
  bestFriend: Friendly
}

type Query {
  dog: Dog
}''',
        (
            "type Dog implements Friendly {\n  bestFriend: Friendly\n}\n\ninter"
            'face Friendly {\n  """The best friend of this friendly thing"""\n '
            " bestFriend: Friendly\n}\n\ntype Query {\n  dog: Dog\n}"
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


def test_builds_a_schema_with_field_arguments() raises:
    check_cycle(
        '''type Query {
  """A field with a single arg"""
  one(
    """This is an int arg"""
    intArg: Int
  ): String

  """A field with a two args"""
  two(
    """This is an list of int arg"""
    listArg: [Int]

    """This is a required arg"""
    requiredArg: Boolean!
  ): String
}''',
        (
            'type Query {\n  """A field with a single arg"""\n  one(\n    """Th'
            'is is an int arg"""\n    intArg: Int\n  ): String\n\n  """A field '
            'with a two args"""\n  two(\n    """This is an list of int arg"""\n'
            '    listArg: [Int]\n\n    """This is a required arg"""\n    requir'
            "edArg: Boolean!\n  ): String\n}"
        ),
    )


def test_builds_a_schema_with_default_value_on_custom_scalar_field() raises:
    check_cycle(
        """scalar CustomScalar

type Query {
  testField(testArg: CustomScalar = "default"): String
}""",
        (
            "scalar CustomScalar\n\ntype Query {\n  testField(testArg: CustomSc"
            'alar = "default"): String\n}'
        ),
    )


def test_builds_a_schema_with_an_enum() raises:
    check_cycle(
        '''schema {
  query: EnumFields
}

type EnumFields {
  """Repeats the arg you give it"""
  food(
    """what kind of food?"""
    kind: Food
  ): Food
}

"""Varieties of food stuffs"""
enum Food {
  """Foods that are vegetables."""
  VEGETABLES
  FRUITS
  OILS @deprecated(reason: "Too fatty")
}''',
        (
            'schema {\n  query: EnumFields\n}\n\ntype EnumFields {\n  """Repeat'
            's the arg you give it"""\n  food(\n    """what kind of food?"""\n '
            '   kind: Food\n  ): Food\n}\n\n"""Varieties of food stuffs"""\nenu'
            'm Food {\n  """Foods that are vegetables."""\n  VEGETABLES\n  FRUI'
            'TS\n  OILS @deprecated(reason: "Too fatty")\n}'
        ),
    )


def test_builds_a_schema_with_an_input_object() raises:
    check_cycle(
        '''"""An input address"""
input Address {
  """What street is this address?"""
  street: String!

  """The city the address is within?"""
  city: String!

  """The country (blank will assume USA)."""
  country: String = "USA"
}

type Query {
  """Get a geocode from an address"""
  geocode(
    """The address to lookup"""
    address: Address
  ): String
}''',
        (
            '"""An input address"""\ninput Address {\n  """What street is this '
            'address?"""\n  street: String!\n\n  """The city the address is wit'
            'hin?"""\n  city: String!\n\n  """The country (blank will assume US'
            'A)."""\n  country: String = "USA"\n}\n\ntype Query {\n  """Get a g'
            'eocode from an address"""\n  geocode(\n    """The address to looku'
            'p"""\n    address: Address\n  ): String\n}'
        ),
    )


def test_builds_a_schema_with_field_arguments_with_default_values() raises:
    check_cycle(
        """input Geo {
  lat: Float
  lon: Float
}

type Query {
  defaultInt(intArg: Int = 30): String
  defaultList(listArg: [Int] = [1, 2, 3]): String
  defaultObject(objArg: Geo = {lat: 37.485, lon: -122.148}): String
  defaultNull(intArg: Int = null): String
  noDefault(intArg: Int): String
}""",
        (
            "input Geo {\n  lat: Float\n  lon: Float\n}\n\ntype Query {\n  defa"
            "ultInt(intArg: Int = 30): String\n  defaultList(listArg: [Int] = ["
            "1, 2, 3]): String\n  defaultObject(objArg: Geo = {lat: 37.485, lon"
            ": -122.148}): String\n  defaultNull(intArg: Int = null): String\n "
            " noDefault(intArg: Int): String\n}"
        ),
    )


def test_builds_a_schema_with_custom_directives() raises:
    check_cycle(
        '''"""This is a custom directive"""
directive @customDirective repeatable on FIELD

type Query {
  string: String
}''',
        (
            '"""This is a custom directive"""\ndirective @customDirective repea'
            "table on FIELD\n\ntype Query {\n  string: String\n}"
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


def test_builds_a_schema_aware_of_deprecation() raises:
    check_cycle(
        '''directive @someDirective(
  """This is a shiny new argument"""
  shinyArg: SomeInputObject

  """This was our design mistake :("""
  oldArg: String @deprecated(reason: "Use shinyArg")
) on QUERY

enum Color {
  """So rosy"""
  RED

  """So grassy"""
  GREEN

  """So calming"""
  BLUE

  """So sickening"""
  MAUVE @deprecated(reason: "No longer in fashion")
}

input SomeInputObject {
  """Nothing special about it, just deprecated for some unknown reason"""
  oldField: String @deprecated(reason: "Don't use it, use newField instead!")

  """Same field but with a new name"""
  newField: String
}

type Query {
  """This is a shiny string field"""
  shinyString: String

  """This is a deprecated string field"""
  deprecatedString: String @deprecated(reason: "Use shinyString")

  """Color of a week"""
  color: Color

  """Some random field"""
  someField(
    """This is a shiny new argument"""
    shinyArg: SomeInputObject

    """This was our design mistake :("""
    oldArg: String @deprecated(reason: "Use shinyArg")
  ): String
}''',
        (
            'directive @someDirective(\n  """This is a shiny new argument"""\n '
            ' shinyArg: SomeInputObject\n\n  """This was our design mistake'
            ' :("""\n  oldArg: String @deprecated(reason: "Use shinyArg")\n) on'
            ' QUERY\n\nenum Color {\n  """So rosy"""\n  RED\n\n  """So'
            ' grassy"""\n  GREEN\n\n  """So calming"""\n  BLUE\n\n  """So'
            ' sickening"""\n  MAUVE @deprecated(reason: "No longer in'
            ' fashion")\n}\n\ninput SomeInputObject {\n  """Nothing special'
            ' about it, just deprecated for some unknown reason"""\n  oldField:'
            " String @deprecated(reason: \"Don't use it, use newField"
            ' instead!")\n\n  """Same field but with a new name"""\n  newField:'
            ' String\n}\n\ntype Query {\n  """This is a shiny string field"""\n'
            '  shinyString: String\n\n  """This is a deprecated string'
            ' field"""\n  deprecatedString: String @deprecated(reason: "Use'
            ' shinyString")\n\n  """Color of a week"""\n  color: Color\n\n '
            ' """Some random field"""\n  someField(\n    """This is a shiny new'
            ' argument"""\n    shinyArg: SomeInputObject\n\n    """This was our'
            ' design mistake :("""\n    oldArg: String @deprecated(reason: "Use'
            ' shinyArg")\n  ): String\n}'
        ),
    )


def test_builds_a_schema_with_empty_deprecation_reasons() raises:
    check_cycle(
        """directive @someDirective(someArg: SomeInputObject @deprecated(reason: "")) on QUERY

type Query {
  someField(someArg: SomeInputObject @deprecated(reason: "")): SomeEnum @deprecated(reason: "")
}

input SomeInputObject {
  someInputField: String @deprecated(reason: "")
}

enum SomeEnum {
  SOME_VALUE @deprecated(reason: "")
}""",
        (
            "directive @someDirective(someArg: SomeInputObject @deprecated(reas"
            'on: "")) on QUERY\n\ntype Query {\n  someField(someArg: SomeInputO'
            'bject @deprecated(reason: "")): SomeEnum @deprecated(reason: "")\n'
            "}\n\ninput SomeInputObject {\n  someInputField: String @deprecated"
            '(reason: "")\n}\n\nenum SomeEnum {\n  SOME_VALUE @deprecated(reaso'
            'n: "")\n}'
        ),
    )


def test_builds_a_schema_with_specifiedby_url() raises:
    check_cycle(
        """scalar Foo @specifiedBy(url: "https://example.com/foo_spec")

type Query {
  foo: Foo
}""",
        (
            'scalar Foo @specifiedBy(url: "https://example.com/foo_spec")\n\nty'
            "pe Query {\n  foo: Foo\n}"
        ),
    )


def test_builds_a_schema_with_oneof_directive() raises:
    check_cycle(
        """type Query {
  someField(someArg: SomeInputObject): String
}

input SomeInputObject @oneOf {
  someInputField1: String
  someInputField2: String
}""",
        (
            "type Query {\n  someField(someArg: SomeInputObject): String\n}\n\n"
            "input SomeInputObject @oneOf {\n  someInputField1: String\n  someI"
            "nputField2: String\n}"
        ),
    )


def test_can_use_client_schema_for_limited_execution() raises:
    check_cycle(
        """scalar CustomScalar

type Query {
  foo(custom1: CustomScalar, custom2: CustomScalar): String
}""",
        (
            "scalar CustomScalar\n\ntype Query {\n  foo(custom1: CustomScalar, "
            "custom2: CustomScalar): String\n}"
        ),
    )


def test_can_build_invalid_schema() raises:
    check_cycle(
        """type Query""",
        "type Query",
    )


def test_throws_when_given_invalid_introspection_throws_when_introspection_is_missing_schema_property() raises:
    check_json(
        "null",
        (
            "ERROR: Invalid or incomplete introspection result. Ensure that you"
            ' are passing "data" property of introspection response and no "err'
            'ors" was returned alongside: null.'
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_introspection_is_missing_schema_property_2() raises:
    check_json(
        "{}",
        (
            "ERROR: Invalid or incomplete introspection result. Ensure that you"
            ' are passing "data" property of introspection response and no "err'
            'ors" was returned alongside: {}.'
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_referenced_unknown_type() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"SCALAR","name":"String","description":null,"specifiedByURL"'
            ':null,"isOneOf":null,"fields":null,"inputFields":null,"interfaces"'
            ':null,"enumValues":null,"possibleTypes":null},{"kind":"INTERFACE",'
            '"name":"SomeInterface","description":null,"specifiedByURL":null,"i'
            'sOneOf":null,"fields":[{"name":"foo","description":null,"args":[],'
            '"type":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecat'
            'ed":false,"deprecationReason":null}],"inputFields":null,"interface'
            's":[],"enumValues":null,"possibleTypes":[]},{"kind":"UNION","name"'
            ':"SomeUnion","description":null,"specifiedByURL":null,"isOneOf":nu'
            'll,"fields":null,"inputFields":null,"interfaces":null,"enumValues"'
            ':null,"possibleTypes":[{"kind":"OBJECT","name":"Query","ofType":nu'
            'll}]},{"kind":"ENUM","name":"SomeEnum","description":null,"specifi'
            'edByURL":null,"isOneOf":null,"fields":null,"inputFields":null,"int'
            'erfaces":null,"enumValues":[{"name":"FOO","description":null,"isDe'
            'precated":false,"deprecationReason":null}],"possibleTypes":null},{'
            '"kind":"INPUT_OBJECT","name":"SomeInputObject","description":null,'
            '"specifiedByURL":null,"isOneOf":false,"fields":null,"inputFields":'
            '[{"name":"foo","description":null,"type":{"kind":"SCALAR","name":"'
            'String","ofType":null},"defaultValue":null,"isDeprecated":false,"d'
            'eprecationReason":null}],"interfaces":null,"enumValues":null,"poss'
            'ibleTypes":null},{"kind":"SCALAR","name":"Boolean","description":n'
            'ull,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputField'
            's":null,"interfaces":null,"enumValues":null,"possibleTypes":null}]'
            ',"directives":[{"name":"SomeDirective","description":null,"isRepea'
            'table":false,"isDeprecated":false,"deprecationReason":null,"locati'
            'ons":["QUERY"],"args":[]}]}}'
        ),
        (
            "ERROR: Invalid or incomplete schema, unknown type: Query. Ensure t"
            "hat a full introspection query is used in order to build a client "
            "schema."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_definition_for_one_of_the_standard_scalars() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[],"type":{"kind":"SCALAR","name":"Float","ofType":null},"isDe'
            'precated":false,"deprecationReason":null}],"inputFields":null,"int'
            'erfaces":[],"enumValues":null,"possibleTypes":null},{"kind":"SCALA'
            'R","name":"Boolean","description":null,"specifiedByURL":null,"isOn'
            'eOf":null,"fields":null,"inputFields":null,"interfaces":null,"enum'
            'Values":null,"possibleTypes":null},{"kind":"SCALAR","name":"String'
            '","description":null,"specifiedByURL":null,"isOneOf":null,"fields"'
            ':null,"inputFields":null,"interfaces":null,"enumValues":null,"poss'
            'ibleTypes":null}],"directives":[]}}'
        ),
        (
            "ERROR: Invalid or incomplete schema, unknown type: Float. Ensure t"
            "hat a full introspection query is used in order to build a client "
            "schema."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_type_reference_is_missing_name() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"kind":"OBJECT"},"mut'
            'ationType":null,"subscriptionType":null,"types":[{"kind":"OBJECT",'
            '"name":"Query","description":null,"specifiedByURL":null,"isOneOf":'
            'null,"fields":[{"name":"foo","description":null,"args":[{"name":"b'
            'ar","description":null,"type":{"kind":"SCALAR","name":"String","of'
            'Type":null},"defaultValue":null,"isDeprecated":false,"deprecationR'
            'eason":null}],"type":{"kind":"SCALAR","name":"String","ofType":nul'
            'l},"isDeprecated":false,"deprecationReason":null}],"inputFields":n'
            'ull,"interfaces":[],"enumValues":null,"possibleTypes":null},{"kind'
            '":"SCALAR","name":"String","description":null,"specifiedByURL":nul'
            'l,"isOneOf":null,"fields":null,"inputFields":null,"interfaces":nul'
            'l,"enumValues":null,"possibleTypes":null},{"kind":"INTERFACE","nam'
            'e":"SomeInterface","description":null,"specifiedByURL":null,"isOne'
            'Of":null,"fields":[{"name":"foo","description":null,"args":[],"typ'
            'e":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated":'
            'false,"deprecationReason":null}],"inputFields":null,"interfaces":['
            '],"enumValues":null,"possibleTypes":[]},{"kind":"UNION","name":"So'
            'meUnion","description":null,"specifiedByURL":null,"isOneOf":null,"'
            'fields":null,"inputFields":null,"interfaces":null,"enumValues":nul'
            'l,"possibleTypes":[{"kind":"OBJECT","name":"Query","ofType":null}]'
            '},{"kind":"ENUM","name":"SomeEnum","description":null,"specifiedBy'
            'URL":null,"isOneOf":null,"fields":null,"inputFields":null,"interfa'
            'ces":null,"enumValues":[{"name":"FOO","description":null,"isDeprec'
            'ated":false,"deprecationReason":null}],"possibleTypes":null},{"kin'
            'd":"INPUT_OBJECT","name":"SomeInputObject","description":null,"spe'
            'cifiedByURL":null,"isOneOf":false,"fields":null,"inputFields":[{"n'
            'ame":"foo","description":null,"type":{"kind":"SCALAR","name":"Stri'
            'ng","ofType":null},"defaultValue":null,"isDeprecated":false,"depre'
            'cationReason":null}],"interfaces":null,"enumValues":null,"possible'
            'Types":null},{"kind":"SCALAR","name":"Boolean","description":null,'
            '"specifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":n'
            'ull,"interfaces":null,"enumValues":null,"possibleTypes":null}],"di'
            'rectives":[{"name":"SomeDirective","description":null,"isRepeatabl'
            'e":false,"isDeprecated":false,"deprecationReason":null,"locations"'
            ':["QUERY"],"args":[]}]}}'
        ),
        'ERROR: Unknown type reference: { kind: "OBJECT" }.',
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_kind() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'name":"Query","description":null,"specifiedByURL":null,"isOneOf":n'
            'ull,"fields":[{"name":"foo","description":null,"args":[{"name":"ba'
            'r","description":null,"type":{"kind":"SCALAR","name":"String","ofT'
            'ype":null},"defaultValue":null,"isDeprecated":false,"deprecationRe'
            'ason":null}],"type":{"kind":"SCALAR","name":"String","ofType":null'
            '},"isDeprecated":false,"deprecationReason":null}],"inputFields":nu'
            'll,"interfaces":[],"enumValues":null,"possibleTypes":null},{"kind"'
            ':"SCALAR","name":"String","description":null,"specifiedByURL":null'
            ',"isOneOf":null,"fields":null,"inputFields":null,"interfaces":null'
            ',"enumValues":null,"possibleTypes":null},{"kind":"INTERFACE","name'
            '":"SomeInterface","description":null,"specifiedByURL":null,"isOneO'
            'f":null,"fields":[{"name":"foo","description":null,"args":[],"type'
            '":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated":f'
            'alse,"deprecationReason":null}],"inputFields":null,"interfaces":[]'
            ',"enumValues":null,"possibleTypes":[]},{"kind":"UNION","name":"Som'
            'eUnion","description":null,"specifiedByURL":null,"isOneOf":null,"f'
            'ields":null,"inputFields":null,"interfaces":null,"enumValues":null'
            ',"possibleTypes":[{"kind":"OBJECT","name":"Query","ofType":null}]}'
            ',{"kind":"ENUM","name":"SomeEnum","description":null,"specifiedByU'
            'RL":null,"isOneOf":null,"fields":null,"inputFields":null,"interfac'
            'es":null,"enumValues":[{"name":"FOO","description":null,"isDepreca'
            'ted":false,"deprecationReason":null}],"possibleTypes":null},{"kind'
            '":"INPUT_OBJECT","name":"SomeInputObject","description":null,"spec'
            'ifiedByURL":null,"isOneOf":false,"fields":null,"inputFields":[{"na'
            'me":"foo","description":null,"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"defaultValue":null,"isDeprecated":false,"deprec'
            'ationReason":null}],"interfaces":null,"enumValues":null,"possibleT'
            'ypes":null},{"kind":"SCALAR","name":"Boolean","description":null,"'
            'specifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":nu'
            'll,"interfaces":null,"enumValues":null,"possibleTypes":null}],"dir'
            'ectives":[{"name":"SomeDirective","description":null,"isRepeatable'
            '":false,"isDeprecated":false,"deprecationReason":null,"locations":'
            '["QUERY"],"args":[]}]}}'
        ),
        (
            "ERROR: Invalid or incomplete introspection result. Ensure that a f"
            "ull introspection query is used in order to build a client schema:"
            ' { name: "Query", description: null, specifiedByURL: null, isOneOf'
            ": null, fields: [[Object]], inputFields: null, interfaces: [], enu"
            "mValues: null, possibleTypes: null }."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_interfaces() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"String","ofType":null},"defaultValue":null,"isDeprecated":fals'
            'e,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"isDeprecated":false,"deprecationReason":null}],'
            '"inputFields":null,"enumValues":null,"possibleTypes":null},{"kind"'
            ':"SCALAR","name":"String","description":null,"specifiedByURL":null'
            ',"isOneOf":null,"fields":null,"inputFields":null,"interfaces":null'
            ',"enumValues":null,"possibleTypes":null},{"kind":"INTERFACE","name'
            '":"SomeInterface","description":null,"specifiedByURL":null,"isOneO'
            'f":null,"fields":[{"name":"foo","description":null,"args":[],"type'
            '":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated":f'
            'alse,"deprecationReason":null}],"inputFields":null,"interfaces":[]'
            ',"enumValues":null,"possibleTypes":[]},{"kind":"UNION","name":"Som'
            'eUnion","description":null,"specifiedByURL":null,"isOneOf":null,"f'
            'ields":null,"inputFields":null,"interfaces":null,"enumValues":null'
            ',"possibleTypes":[{"kind":"OBJECT","name":"Query","ofType":null}]}'
            ',{"kind":"ENUM","name":"SomeEnum","description":null,"specifiedByU'
            'RL":null,"isOneOf":null,"fields":null,"inputFields":null,"interfac'
            'es":null,"enumValues":[{"name":"FOO","description":null,"isDepreca'
            'ted":false,"deprecationReason":null}],"possibleTypes":null},{"kind'
            '":"INPUT_OBJECT","name":"SomeInputObject","description":null,"spec'
            'ifiedByURL":null,"isOneOf":false,"fields":null,"inputFields":[{"na'
            'me":"foo","description":null,"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"defaultValue":null,"isDeprecated":false,"deprec'
            'ationReason":null}],"interfaces":null,"enumValues":null,"possibleT'
            'ypes":null},{"kind":"SCALAR","name":"Boolean","description":null,"'
            'specifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":nu'
            'll,"interfaces":null,"enumValues":null,"possibleTypes":null}],"dir'
            'ectives":[{"name":"SomeDirective","description":null,"isRepeatable'
            '":false,"isDeprecated":false,"deprecationReason":null,"locations":'
            '["QUERY"],"args":[]}]}}'
        ),
        (
            'ERROR: Introspection result missing interfaces: { kind: "OBJECT", '
            'name: "Query", description: null, specifiedByURL: null, isOneOf: n'
            "ull, fields: [[Object]], inputFields: null, enumValues: null, poss"
            "ibleTypes: null }."
        ),
    )


def test_throws_when_given_invalid_introspection_legacy_support_for_interfaces_with_null_as_interfaces_field() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"String","ofType":null},"defaultValue":null,"isDeprecated":fals'
            'e,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"isDeprecated":false,"deprecationReason":null}],'
            '"inputFields":null,"interfaces":[],"enumValues":null,"possibleType'
            's":null},{"kind":"SCALAR","name":"String","description":null,"spec'
            'ifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":null,"'
            'interfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"'
            'INTERFACE","name":"SomeInterface","description":null,"specifiedByU'
            'RL":null,"isOneOf":null,"fields":[{"name":"foo","description":null'
            ',"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},'
            '"isDeprecated":false,"deprecationReason":null}],"inputFields":null'
            ',"interfaces":null,"enumValues":null,"possibleTypes":[]},{"kind":"'
            'UNION","name":"SomeUnion","description":null,"specifiedByURL":null'
            ',"isOneOf":null,"fields":null,"inputFields":null,"interfaces":null'
            ',"enumValues":null,"possibleTypes":[{"kind":"OBJECT","name":"Query'
            '","ofType":null}]},{"kind":"ENUM","name":"SomeEnum","description":'
            'null,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputFiel'
            'ds":null,"interfaces":null,"enumValues":[{"name":"FOO","descriptio'
            'n":null,"isDeprecated":false,"deprecationReason":null}],"possibleT'
            'ypes":null},{"kind":"INPUT_OBJECT","name":"SomeInputObject","descr'
            'iption":null,"specifiedByURL":null,"isOneOf":false,"fields":null,"'
            'inputFields":[{"name":"foo","description":null,"type":{"kind":"SCA'
            'LAR","name":"String","ofType":null},"defaultValue":null,"isDepreca'
            'ted":false,"deprecationReason":null}],"interfaces":null,"enumValue'
            's":null,"possibleTypes":null},{"kind":"SCALAR","name":"Boolean","d'
            'escription":null,"specifiedByURL":null,"isOneOf":null,"fields":nul'
            'l,"inputFields":null,"interfaces":null,"enumValues":null,"possible'
            'Types":null}],"directives":[{"name":"SomeDirective","description":'
            'null,"isRepeatable":false,"isDeprecated":false,"deprecationReason"'
            ':null,"locations":["QUERY"],"args":[]}]}}'
        ),
        (
            "directive @SomeDirective on QUERY\n\ntype Query {\n  foo(bar: Stri"
            "ng): String\n}\n\ninterface SomeInterface {\n  foo: String\n}\n\nu"
            "nion SomeUnion = Query\n\nenum SomeEnum {\n  FOO\n}\n\ninput SomeI"
            "nputObject {\n  foo: String\n}"
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_fields() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"inputFields":null,"interfaces":[],"enumValues'
            '":null,"possibleTypes":null},{"kind":"SCALAR","name":"String","des'
            'cription":null,"specifiedByURL":null,"isOneOf":null,"fields":null,'
            '"inputFields":null,"interfaces":null,"enumValues":null,"possibleTy'
            'pes":null},{"kind":"INTERFACE","name":"SomeInterface","description'
            '":null,"specifiedByURL":null,"isOneOf":null,"fields":[{"name":"foo'
            '","description":null,"args":[],"type":{"kind":"SCALAR","name":"Str'
            'ing","ofType":null},"isDeprecated":false,"deprecationReason":null}'
            '],"inputFields":null,"interfaces":[],"enumValues":null,"possibleTy'
            'pes":[]},{"kind":"UNION","name":"SomeUnion","description":null,"sp'
            'ecifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":null'
            ',"interfaces":null,"enumValues":null,"possibleTypes":[{"kind":"OBJ'
            'ECT","name":"Query","ofType":null}]},{"kind":"ENUM","name":"SomeEn'
            'um","description":null,"specifiedByURL":null,"isOneOf":null,"field'
            's":null,"inputFields":null,"interfaces":null,"enumValues":[{"name"'
            ':"FOO","description":null,"isDeprecated":false,"deprecationReason"'
            ':null}],"possibleTypes":null},{"kind":"INPUT_OBJECT","name":"SomeI'
            'nputObject","description":null,"specifiedByURL":null,"isOneOf":fal'
            'se,"fields":null,"inputFields":[{"name":"foo","description":null,"'
            'type":{"kind":"SCALAR","name":"String","ofType":null},"defaultValu'
            'e":null,"isDeprecated":false,"deprecationReason":null}],"interface'
            's":null,"enumValues":null,"possibleTypes":null},{"kind":"SCALAR","'
            'name":"Boolean","description":null,"specifiedByURL":null,"isOneOf"'
            ':null,"fields":null,"inputFields":null,"interfaces":null,"enumValu'
            'es":null,"possibleTypes":null}],"directives":[{"name":"SomeDirecti'
            've","description":null,"isRepeatable":false,"isDeprecated":false,"'
            'deprecationReason":null,"locations":["QUERY"],"args":[]}]}}'
        ),
        (
            'ERROR: Introspection result missing fields: { kind: "OBJECT", name'
            ': "Query", description: null, specifiedByURL: null, isOneOf: null,'
            " inputFields: null, interfaces: [], enumValues: null, possibleType"
            "s: null }."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_field_args() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ty'
            'pe":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated"'
            ':false,"deprecationReason":null}],"inputFields":null,"interfaces":'
            '[],"enumValues":null,"possibleTypes":null},{"kind":"SCALAR","name"'
            ':"String","description":null,"specifiedByURL":null,"isOneOf":null,'
            '"fields":null,"inputFields":null,"interfaces":null,"enumValues":nu'
            'll,"possibleTypes":null},{"kind":"INTERFACE","name":"SomeInterface'
            '","description":null,"specifiedByURL":null,"isOneOf":null,"fields"'
            ':[{"name":"foo","description":null,"args":[],"type":{"kind":"SCALA'
            'R","name":"String","ofType":null},"isDeprecated":false,"deprecatio'
            'nReason":null}],"inputFields":null,"interfaces":[],"enumValues":nu'
            'll,"possibleTypes":[]},{"kind":"UNION","name":"SomeUnion","descrip'
            'tion":null,"specifiedByURL":null,"isOneOf":null,"fields":null,"inp'
            'utFields":null,"interfaces":null,"enumValues":null,"possibleTypes"'
            ':[{"kind":"OBJECT","name":"Query","ofType":null}]},{"kind":"ENUM",'
            '"name":"SomeEnum","description":null,"specifiedByURL":null,"isOneO'
            'f":null,"fields":null,"inputFields":null,"interfaces":null,"enumVa'
            'lues":[{"name":"FOO","description":null,"isDeprecated":false,"depr'
            'ecationReason":null}],"possibleTypes":null},{"kind":"INPUT_OBJECT"'
            ',"name":"SomeInputObject","description":null,"specifiedByURL":null'
            ',"isOneOf":false,"fields":null,"inputFields":[{"name":"foo","descr'
            'iption":null,"type":{"kind":"SCALAR","name":"String","ofType":null'
            '},"defaultValue":null,"isDeprecated":false,"deprecationReason":nul'
            'l}],"interfaces":null,"enumValues":null,"possibleTypes":null},{"ki'
            'nd":"SCALAR","name":"Boolean","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":null,"inputFields":null,"interfaces":'
            'null,"enumValues":null,"possibleTypes":null}],"directives":[{"name'
            '":"SomeDirective","description":null,"isRepeatable":false,"isDepre'
            'cated":false,"deprecationReason":null,"locations":["QUERY"],"args"'
            ":[]}]}}"
        ),
        (
            'ERROR: Introspection result missing field args: { name: "foo", des'
            'cription: null, type: { kind: "SCALAR", name: "String", ofType: nu'
            "ll }, isDeprecated: false, deprecationReason: null }."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_output_type_is_used_as_an_arg_type() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"SomeUnion","ofType":null},"defaultValue":null,"isDeprecated":f'
            'alse,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"St'
            'ring","ofType":null},"isDeprecated":false,"deprecationReason":null'
            '}],"inputFields":null,"interfaces":[],"enumValues":null,"possibleT'
            'ypes":null},{"kind":"SCALAR","name":"String","description":null,"s'
            'pecifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":nul'
            'l,"interfaces":null,"enumValues":null,"possibleTypes":null},{"kind'
            '":"INTERFACE","name":"SomeInterface","description":null,"specified'
            'ByURL":null,"isOneOf":null,"fields":[{"name":"foo","description":n'
            'ull,"args":[],"type":{"kind":"SCALAR","name":"String","ofType":nul'
            'l},"isDeprecated":false,"deprecationReason":null}],"inputFields":n'
            'ull,"interfaces":[],"enumValues":null,"possibleTypes":[]},{"kind":'
            '"UNION","name":"SomeUnion","description":null,"specifiedByURL":nul'
            'l,"isOneOf":null,"fields":null,"inputFields":null,"interfaces":nul'
            'l,"enumValues":null,"possibleTypes":[{"kind":"OBJECT","name":"Quer'
            'y","ofType":null}]},{"kind":"ENUM","name":"SomeEnum","description"'
            ':null,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputFie'
            'lds":null,"interfaces":null,"enumValues":[{"name":"FOO","descripti'
            'on":null,"isDeprecated":false,"deprecationReason":null}],"possible'
            'Types":null},{"kind":"INPUT_OBJECT","name":"SomeInputObject","desc'
            'ription":null,"specifiedByURL":null,"isOneOf":false,"fields":null,'
            '"inputFields":[{"name":"foo","description":null,"type":{"kind":"SC'
            'ALAR","name":"String","ofType":null},"defaultValue":null,"isDeprec'
            'ated":false,"deprecationReason":null}],"interfaces":null,"enumValu'
            'es":null,"possibleTypes":null},{"kind":"SCALAR","name":"Boolean","'
            'description":null,"specifiedByURL":null,"isOneOf":null,"fields":nu'
            'll,"inputFields":null,"interfaces":null,"enumValues":null,"possibl'
            'eTypes":null}],"directives":[{"name":"SomeDirective","description"'
            ':null,"isRepeatable":false,"isDeprecated":false,"deprecationReason'
            '":null,"locations":["QUERY"],"args":[]}]}}'
        ),
        (
            "ERROR: Introspection must provide input type for arguments, but re"
            "ceived: SomeUnion."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_input_type_is_used_as_a_field_type() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"String","ofType":null},"defaultValue":null,"isDeprecated":fals'
            'e,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"SomeI'
            'nputObject","ofType":null},"isDeprecated":false,"deprecationReason'
            '":null}],"inputFields":null,"interfaces":[],"enumValues":null,"pos'
            'sibleTypes":null},{"kind":"SCALAR","name":"String","description":n'
            'ull,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputField'
            's":null,"interfaces":null,"enumValues":null,"possibleTypes":null},'
            '{"kind":"INTERFACE","name":"SomeInterface","description":null,"spe'
            'cifiedByURL":null,"isOneOf":null,"fields":[{"name":"foo","descript'
            'ion":null,"args":[],"type":{"kind":"SCALAR","name":"String","ofTyp'
            'e":null},"isDeprecated":false,"deprecationReason":null}],"inputFie'
            'lds":null,"interfaces":[],"enumValues":null,"possibleTypes":[]},{"'
            'kind":"UNION","name":"SomeUnion","description":null,"specifiedByUR'
            'L":null,"isOneOf":null,"fields":null,"inputFields":null,"interface'
            's":null,"enumValues":null,"possibleTypes":[{"kind":"OBJECT","name"'
            ':"Query","ofType":null}]},{"kind":"ENUM","name":"SomeEnum","descri'
            'ption":null,"specifiedByURL":null,"isOneOf":null,"fields":null,"in'
            'putFields":null,"interfaces":null,"enumValues":[{"name":"FOO","des'
            'cription":null,"isDeprecated":false,"deprecationReason":null}],"po'
            'ssibleTypes":null},{"kind":"INPUT_OBJECT","name":"SomeInputObject"'
            ',"description":null,"specifiedByURL":null,"isOneOf":false,"fields"'
            ':null,"inputFields":[{"name":"foo","description":null,"type":{"kin'
            'd":"SCALAR","name":"String","ofType":null},"defaultValue":null,"is'
            'Deprecated":false,"deprecationReason":null}],"interfaces":null,"en'
            'umValues":null,"possibleTypes":null},{"kind":"SCALAR","name":"Bool'
            'ean","description":null,"specifiedByURL":null,"isOneOf":null,"fiel'
            'ds":null,"inputFields":null,"interfaces":null,"enumValues":null,"p'
            'ossibleTypes":null}],"directives":[{"name":"SomeDirective","descri'
            'ption":null,"isRepeatable":false,"isDeprecated":false,"deprecation'
            'Reason":null,"locations":["QUERY"],"args":[]}]}}'
        ),
        (
            "ERROR: Introspection must provide output type for fields, but rece"
            "ived: SomeInputObject."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_possibletypes() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"String","ofType":null},"defaultValue":null,"isDeprecated":fals'
            'e,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"isDeprecated":false,"deprecationReason":null}],'
            '"inputFields":null,"interfaces":[],"enumValues":null,"possibleType'
            's":null},{"kind":"SCALAR","name":"String","description":null,"spec'
            'ifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":null,"'
            'interfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"'
            'INTERFACE","name":"SomeInterface","description":null,"specifiedByU'
            'RL":null,"isOneOf":null,"fields":[{"name":"foo","description":null'
            ',"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},'
            '"isDeprecated":false,"deprecationReason":null}],"inputFields":null'
            ',"interfaces":[],"enumValues":null,"possibleTypes":[]},{"kind":"UN'
            'ION","name":"SomeUnion","description":null,"specifiedByURL":null,"'
            'isOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"'
            'enumValues":null},{"kind":"ENUM","name":"SomeEnum","description":n'
            'ull,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputField'
            's":null,"interfaces":null,"enumValues":[{"name":"FOO","description'
            '":null,"isDeprecated":false,"deprecationReason":null}],"possibleTy'
            'pes":null},{"kind":"INPUT_OBJECT","name":"SomeInputObject","descri'
            'ption":null,"specifiedByURL":null,"isOneOf":false,"fields":null,"i'
            'nputFields":[{"name":"foo","description":null,"type":{"kind":"SCAL'
            'AR","name":"String","ofType":null},"defaultValue":null,"isDeprecat'
            'ed":false,"deprecationReason":null}],"interfaces":null,"enumValues'
            '":null,"possibleTypes":null},{"kind":"SCALAR","name":"Boolean","de'
            'scription":null,"specifiedByURL":null,"isOneOf":null,"fields":null'
            ',"inputFields":null,"interfaces":null,"enumValues":null,"possibleT'
            'ypes":null}],"directives":[{"name":"SomeDirective","description":n'
            'ull,"isRepeatable":false,"isDeprecated":false,"deprecationReason":'
            'null,"locations":["QUERY"],"args":[]}]}}'
        ),
        (
            'ERROR: Introspection result missing possibleTypes: { kind: "UNION"'
            ', name: "SomeUnion", description: null, specifiedByURL: null, isOn'
            "eOf: null, fields: null, inputFields: null, interfaces: null, enum"
            "Values: null }."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_enumvalues() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"String","ofType":null},"defaultValue":null,"isDeprecated":fals'
            'e,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"isDeprecated":false,"deprecationReason":null}],'
            '"inputFields":null,"interfaces":[],"enumValues":null,"possibleType'
            's":null},{"kind":"SCALAR","name":"String","description":null,"spec'
            'ifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":null,"'
            'interfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"'
            'INTERFACE","name":"SomeInterface","description":null,"specifiedByU'
            'RL":null,"isOneOf":null,"fields":[{"name":"foo","description":null'
            ',"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},'
            '"isDeprecated":false,"deprecationReason":null}],"inputFields":null'
            ',"interfaces":[],"enumValues":null,"possibleTypes":[]},{"kind":"UN'
            'ION","name":"SomeUnion","description":null,"specifiedByURL":null,"'
            'isOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"'
            'enumValues":null,"possibleTypes":[{"kind":"OBJECT","name":"Query",'
            '"ofType":null}]},{"kind":"ENUM","name":"SomeEnum","description":nu'
            'll,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputFields'
            '":null,"interfaces":null,"possibleTypes":null},{"kind":"INPUT_OBJE'
            'CT","name":"SomeInputObject","description":null,"specifiedByURL":n'
            'ull,"isOneOf":false,"fields":null,"inputFields":[{"name":"foo","de'
            'scription":null,"type":{"kind":"SCALAR","name":"String","ofType":n'
            'ull},"defaultValue":null,"isDeprecated":false,"deprecationReason":'
            'null}],"interfaces":null,"enumValues":null,"possibleTypes":null},{'
            '"kind":"SCALAR","name":"Boolean","description":null,"specifiedByUR'
            'L":null,"isOneOf":null,"fields":null,"inputFields":null,"interface'
            's":null,"enumValues":null,"possibleTypes":null}],"directives":[{"n'
            'ame":"SomeDirective","description":null,"isRepeatable":false,"isDe'
            'precated":false,"deprecationReason":null,"locations":["QUERY"],"ar'
            'gs":[]}]}}'
        ),
        (
            'ERROR: Introspection result missing enumValues: { kind: "ENUM", na'
            'me: "SomeEnum", description: null, specifiedByURL: null, isOneOf: '
            "null, fields: null, inputFields: null, interfaces: null, possibleT"
            "ypes: null }."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_inputfields() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"String","ofType":null},"defaultValue":null,"isDeprecated":fals'
            'e,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"isDeprecated":false,"deprecationReason":null}],'
            '"inputFields":null,"interfaces":[],"enumValues":null,"possibleType'
            's":null},{"kind":"SCALAR","name":"String","description":null,"spec'
            'ifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":null,"'
            'interfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"'
            'INTERFACE","name":"SomeInterface","description":null,"specifiedByU'
            'RL":null,"isOneOf":null,"fields":[{"name":"foo","description":null'
            ',"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},'
            '"isDeprecated":false,"deprecationReason":null}],"inputFields":null'
            ',"interfaces":[],"enumValues":null,"possibleTypes":[]},{"kind":"UN'
            'ION","name":"SomeUnion","description":null,"specifiedByURL":null,"'
            'isOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"'
            'enumValues":null,"possibleTypes":[{"kind":"OBJECT","name":"Query",'
            '"ofType":null}]},{"kind":"ENUM","name":"SomeEnum","description":nu'
            'll,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputFields'
            '":null,"interfaces":null,"enumValues":[{"name":"FOO","description"'
            ':null,"isDeprecated":false,"deprecationReason":null}],"possibleTyp'
            'es":null},{"kind":"INPUT_OBJECT","name":"SomeInputObject","descrip'
            'tion":null,"specifiedByURL":null,"isOneOf":false,"fields":null,"in'
            'terfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"SC'
            'ALAR","name":"Boolean","description":null,"specifiedByURL":null,"i'
            'sOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"e'
            'numValues":null,"possibleTypes":null}],"directives":[{"name":"Some'
            'Directive","description":null,"isRepeatable":false,"isDeprecated":'
            'false,"deprecationReason":null,"locations":["QUERY"],"args":[]}]}}'
        ),
        (
            'ERROR: Introspection result missing inputFields: { kind: "INPUT_OB'
            'JECT", name: "SomeInputObject", description: null, specifiedByURL:'
            " null, isOneOf: false, fields: null, interfaces: null, enumValues:"
            " null, possibleTypes: null }."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_directive_locations() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"String","ofType":null},"defaultValue":null,"isDeprecated":fals'
            'e,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"isDeprecated":false,"deprecationReason":null}],'
            '"inputFields":null,"interfaces":[],"enumValues":null,"possibleType'
            's":null},{"kind":"SCALAR","name":"String","description":null,"spec'
            'ifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":null,"'
            'interfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"'
            'INTERFACE","name":"SomeInterface","description":null,"specifiedByU'
            'RL":null,"isOneOf":null,"fields":[{"name":"foo","description":null'
            ',"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},'
            '"isDeprecated":false,"deprecationReason":null}],"inputFields":null'
            ',"interfaces":[],"enumValues":null,"possibleTypes":[]},{"kind":"UN'
            'ION","name":"SomeUnion","description":null,"specifiedByURL":null,"'
            'isOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"'
            'enumValues":null,"possibleTypes":[{"kind":"OBJECT","name":"Query",'
            '"ofType":null}]},{"kind":"ENUM","name":"SomeEnum","description":nu'
            'll,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputFields'
            '":null,"interfaces":null,"enumValues":[{"name":"FOO","description"'
            ':null,"isDeprecated":false,"deprecationReason":null}],"possibleTyp'
            'es":null},{"kind":"INPUT_OBJECT","name":"SomeInputObject","descrip'
            'tion":null,"specifiedByURL":null,"isOneOf":false,"fields":null,"in'
            'putFields":[{"name":"foo","description":null,"type":{"kind":"SCALA'
            'R","name":"String","ofType":null},"defaultValue":null,"isDeprecate'
            'd":false,"deprecationReason":null}],"interfaces":null,"enumValues"'
            ':null,"possibleTypes":null},{"kind":"SCALAR","name":"Boolean","des'
            'cription":null,"specifiedByURL":null,"isOneOf":null,"fields":null,'
            '"inputFields":null,"interfaces":null,"enumValues":null,"possibleTy'
            'pes":null}],"directives":[{"name":"SomeDirective","description":nu'
            'll,"isRepeatable":false,"isDeprecated":false,"deprecationReason":n'
            'ull,"args":[]}]}}'
        ),
        (
            'ERROR: Introspection result missing directive locations: { name: "'
            'SomeDirective", description: null, isRepeatable: false, isDeprecat'
            "ed: false, deprecationReason: null, args: [] }."
        ),
    )


def test_throws_when_given_invalid_introspection_throws_when_missing_directive_args() raises:
    check_json(
        (
            '{"__schema":{"description":null,"queryType":{"name":"Query","kind"'
            ':"OBJECT"},"mutationType":null,"subscriptionType":null,"types":[{"'
            'kind":"OBJECT","name":"Query","description":null,"specifiedByURL":'
            'null,"isOneOf":null,"fields":[{"name":"foo","description":null,"ar'
            'gs":[{"name":"bar","description":null,"type":{"kind":"SCALAR","nam'
            'e":"String","ofType":null},"defaultValue":null,"isDeprecated":fals'
            'e,"deprecationReason":null}],"type":{"kind":"SCALAR","name":"Strin'
            'g","ofType":null},"isDeprecated":false,"deprecationReason":null}],'
            '"inputFields":null,"interfaces":[],"enumValues":null,"possibleType'
            's":null},{"kind":"SCALAR","name":"String","description":null,"spec'
            'ifiedByURL":null,"isOneOf":null,"fields":null,"inputFields":null,"'
            'interfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"'
            'INTERFACE","name":"SomeInterface","description":null,"specifiedByU'
            'RL":null,"isOneOf":null,"fields":[{"name":"foo","description":null'
            ',"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},'
            '"isDeprecated":false,"deprecationReason":null}],"inputFields":null'
            ',"interfaces":[],"enumValues":null,"possibleTypes":[]},{"kind":"UN'
            'ION","name":"SomeUnion","description":null,"specifiedByURL":null,"'
            'isOneOf":null,"fields":null,"inputFields":null,"interfaces":null,"'
            'enumValues":null,"possibleTypes":[{"kind":"OBJECT","name":"Query",'
            '"ofType":null}]},{"kind":"ENUM","name":"SomeEnum","description":nu'
            'll,"specifiedByURL":null,"isOneOf":null,"fields":null,"inputFields'
            '":null,"interfaces":null,"enumValues":[{"name":"FOO","description"'
            ':null,"isDeprecated":false,"deprecationReason":null}],"possibleTyp'
            'es":null},{"kind":"INPUT_OBJECT","name":"SomeInputObject","descrip'
            'tion":null,"specifiedByURL":null,"isOneOf":false,"fields":null,"in'
            'putFields":[{"name":"foo","description":null,"type":{"kind":"SCALA'
            'R","name":"String","ofType":null},"defaultValue":null,"isDeprecate'
            'd":false,"deprecationReason":null}],"interfaces":null,"enumValues"'
            ':null,"possibleTypes":null},{"kind":"SCALAR","name":"Boolean","des'
            'cription":null,"specifiedByURL":null,"isOneOf":null,"fields":null,'
            '"inputFields":null,"interfaces":null,"enumValues":null,"possibleTy'
            'pes":null}],"directives":[{"name":"SomeDirective","description":nu'
            'll,"isRepeatable":false,"isDeprecated":false,"deprecationReason":n'
            'ull,"locations":["QUERY"]}]}}'
        ),
        (
            'ERROR: Introspection result missing directive args: { name: "SomeD'
            'irective", description: null, isRepeatable: false, isDeprecated: f'
            'alse, deprecationReason: null, locations: ["QUERY"] }.'
        ),
    )


def test_very_deep_decorators_are_not_supported_fails_on_very_deep_8_levels_lists() raises:
    check_cycle(
        """type Query {
  foo: [[[[[[[[[[String]]]]]]]]]]
}""",
        "ERROR: Decorated type deeper than introspection query.",
    )


def test_very_deep_decorators_are_not_supported_fails_on_a_very_deep_8_levels_non_null() raises:
    check_cycle(
        """type Query {
  foo: [[[[[String!]!]!]!]!]
}""",
        "ERROR: Decorated type deeper than introspection query.",
    )


def test_very_deep_decorators_are_not_supported_succeeds_on_deep_8_levels_types() raises:
    check_cycle(
        """type Query {
  foo: [[[[String!]!]!]!]!
}""",
        "type Query {\n  foo: [[[[String!]!]!]!]!\n}",
    )


def test_prevents_infinite_recursion_on_invalid_introspection_recursive_interfaces() raises:
    check_cycle(
        """type Query {
  foo: Foo
}

type Foo implements Foo {
  foo: String
}""",
        "ERROR: Expected Foo to be a GraphQL Interface type.",
    )


def test_prevents_infinite_recursion_on_invalid_introspection_recursive_union() raises:
    check_cycle(
        """type Query {
  foo: Foo
}

union Foo = Foo""",
        "ERROR: Expected Foo to be a GraphQL Object type.",
    )


# --- not upstream: checked against graphql-js 16.14.2 in Node.js ---------


def test_name_not_a_string() raises:
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String","description":null,"specifiedByURL":null},{"kind'
            '":"OBJECT","name":"Query","description":null,"interfaces":[],"fiel'
            'ds":[{"name":"f","description":null,"args":[],"type":{"kind":"OBJE'
            'CT","name":5},"isDeprecated":false,"deprecationReason":null}]}],"d'
            'irectives":[]}}'
        ),
        (
            "ERROR: Invalid or incomplete schema, unknown type: 5. Ensure that "
            "a full introspection query is used in order to build a client sche"
            "ma."
        ),
    )


def test_non_null_of_non_null() raises:
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


def test_default_syntax_error() raises:
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


def test_default_with_variable() raises:
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


def test_null_interfaces_on_object() raises:
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


def test_type_without_name() raises:
    check_json(
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":[{"kind":"SCALAR'
            '","name":"String","description":null,"specifiedByURL":null},{"kind'
            '":"OBJECT","name":"Query","description":null,"interfaces":[],"fiel'
            'ds":[{"name":"f","description":null,"args":[],"type":{"kind":"SCAL'
            'AR","name":"String"},"isDeprecated":false,"deprecationReason":null'
            '}]},{"kind":"SCALAR"}],"directives":[]}}'
        ),
        (
            "ERROR: Invalid or incomplete introspection result. Ensure that a f"
            "ull introspection query is used in order to build a client schema:"
            ' { kind: "SCALAR" }.'
        ),
    )


def test_no_types() raises:
    check_json(
        '{"__schema":{"queryType":null,"directives":[]}}',
        "ERROR: list is not iterable",
    )


def test_no_directives() raises:
    check_json(
        (
            '{"__schema":{"queryType":null,"types":[{"kind":"SCALAR","name":"St'
            'ring","description":null,"specifiedByURL":null}]}}'
        ),
        "",
    )


def test_a_directive_with_no_locations() raises:
    check_json(
        (
            '{"__schema": {"queryType": null, "types": [], "directives":'
            ' [{"name": "x", "description": null, "isRepeatable": false,'
            ' "locations": [], "args": []}]}}'
        ),
        "ERROR: A directive must have at least one location: @x.",
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


def test_type_reference_names_as_javascript_keys() raises:
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


def test_a_kind_that_is_not_a_string() raises:
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


def test_an_empty_name_and_empty_members() raises:
    check_json(
        _ref('""'),
        'ERROR: Unknown type reference: { kind: "OBJECT", name: "" }.',
    )
    check_json(
        (
            '{"__schema":{"queryType":null,"directives":[],"types":[{"kind":"ENUM",'
            '"name":"E","description":null,"enumValues":[]},{"kind":"INPUT_OBJECT",'
            '"name":"I","description":null,"inputFields":[],"isOneOf":false}]}}'
        ),
        "enum E\n\ninput I",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
