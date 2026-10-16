# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the introspection resolvers, ported from graphql-js 16.14.2
`src/type/__tests__/introspection-test.ts`.

Each upstream execution is ported with the SDL that graphql-js
`printSchema` gives for its schema, and its query. The expected results
are those of graphql-js `executeSync` on the schema built from that SDL.
Upstream runs `graphqlSync`, which validates first; the queries are valid
except in `fails as expected on the __type root field without an arg`,
where this port gets the execution error of graphql-js instead of the
validation error.

Upstream cases that are not ported:

- `identifies deprecated directives` and `respects the includeDeprecated
  parameter for directives`: a deprecated directive cannot be written in
  SDL, and graphql-js 16.14.2 cannot parse the SDL it prints for one.
"""

from std.testing import TestSuite, assert_equal, assert_false
from _helpers import json_value, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.introspection import get_introspection_query
from gql_execution.value import Values
from gql_schema.build import build_schema


def check(
    sdl: String, query: String, variables: String, expected: String
) raises:
    var schema = build_schema(sdl)
    var args = ExecutionArgs()
    if variables != "":
        args.variable_values = json_value(args.values, variables)
    assert_equal(run_query(schema, query, args), expected)


def fail_field(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    raise Error("Called on " + info.field_name)


def fail_type(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    raise Error("Called on an abstract type")


def test_introspection_does_not_call_the_global_resolvers() raises:
    var schema = build_schema(
        """
      type Query {
        someField(
          someArg: String
        ): SomeType
      }

      type SomeType {
        someField: SomeUnion
      }

      union SomeUnion = SomeType
    """
    )
    var args = ExecutionArgs()
    args.resolvers.field_resolver(fail_field)
    args.resolvers.default_type_resolver(fail_type)
    var result = run_query(schema, get_introspection_query(), args)
    assert_false('"errors"' in result)


def test_executes_an_introspection_query() raises:
    check(
        """schema {
  query: SomeObject
}

type SomeObject {
  someField: String
}""",
        """
    query IntrospectionQuery {
      __schema {
        
        queryType { name kind }
        mutationType { name kind }
        subscriptionType { name kind }
        types {
          ...FullType
        }
        directives {
          name
          
          isRepeatable
          
          
          locations
          args {
            ...InputValue
          }
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      
      specifiedByURL
      
      fields(includeDeprecated: true) {
        name
        
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      
      type { ...TypeRef }
      defaultValue
      
      
    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        name
        kind
        ofType {
          name
          kind
          ofType {
            name
            kind
            ofType {
              name
              kind
              ofType {
                name
                kind
                ofType {
                  name
                  kind
                  ofType {
                    name
                    kind
                    ofType {
                      name
                      kind
                      ofType {
                        name
                        kind
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  """,
        "",
        (
            '{"data":{"__schema":{"queryType":{"name":"SomeObject","kind":"OBJE'
            'CT"},"mutationType":null,"subscriptionType":null,"types":[{"kind":'
            '"OBJECT","name":"SomeObject","specifiedByURL":null,"fields":[{"nam'
            'e":"someField","args":[],"type":{"kind":"SCALAR","name":"String","'
            'ofType":null},"isDeprecated":false,"deprecationReason":null}],"inp'
            'utFields":null,"interfaces":[],"enumValues":null,"possibleTypes":n'
            'ull},{"kind":"SCALAR","name":"String","specifiedByURL":null,"field'
            's":null,"inputFields":null,"interfaces":null,"enumValues":null,"po'
            'ssibleTypes":null},{"kind":"SCALAR","name":"Boolean","specifiedByU'
            'RL":null,"fields":null,"inputFields":null,"interfaces":null,"enumV'
            'alues":null,"possibleTypes":null},{"kind":"OBJECT","name":"__Schem'
            'a","specifiedByURL":null,"fields":[{"name":"description","args":[]'
            ',"type":{"kind":"SCALAR","name":"String","ofType":null},"isDepreca'
            'ted":false,"deprecationReason":null},{"name":"types","args":[],"ty'
            'pe":{"kind":"NON_NULL","name":null,"ofType":{"name":null,"kind":"L'
            'IST","ofType":{"name":null,"kind":"NON_NULL","ofType":{"name":"__T'
            'ype","kind":"OBJECT","ofType":null}}}},"isDeprecated":false,"depre'
            'cationReason":null},{"name":"queryType","args":[],"type":{"kind":"'
            'NON_NULL","name":null,"ofType":{"name":"__Type","kind":"OBJECT","o'
            'fType":null}},"isDeprecated":false,"deprecationReason":null},{"nam'
            'e":"mutationType","args":[],"type":{"kind":"OBJECT","name":"__Type'
            '","ofType":null},"isDeprecated":false,"deprecationReason":null},{"'
            'name":"subscriptionType","args":[],"type":{"kind":"OBJECT","name":'
            '"__Type","ofType":null},"isDeprecated":false,"deprecationReason":n'
            'ull},{"name":"directives","args":[{"name":"includeDeprecated","typ'
            'e":{"kind":"NON_NULL","name":null,"ofType":{"name":"Boolean","kind'
            '":"SCALAR","ofType":null}},"defaultValue":"false"}],"type":{"kind"'
            ':"NON_NULL","name":null,"ofType":{"name":null,"kind":"LIST","ofTyp'
            'e":{"name":null,"kind":"NON_NULL","ofType":{"name":"__Directive","'
            'kind":"OBJECT","ofType":null}}}},"isDeprecated":false,"deprecation'
            'Reason":null}],"inputFields":null,"interfaces":[],"enumValues":nul'
            'l,"possibleTypes":null},{"kind":"OBJECT","name":"__Type","specifie'
            'dByURL":null,"fields":[{"name":"kind","args":[],"type":{"kind":"NO'
            'N_NULL","name":null,"ofType":{"name":"__TypeKind","kind":"ENUM","o'
            'fType":null}},"isDeprecated":false,"deprecationReason":null},{"nam'
            'e":"name","args":[],"type":{"kind":"SCALAR","name":"String","ofTyp'
            'e":null},"isDeprecated":false,"deprecationReason":null},{"name":"d'
            'escription","args":[],"type":{"kind":"SCALAR","name":"String","ofT'
            'ype":null},"isDeprecated":false,"deprecationReason":null},{"name":'
            '"specifiedByURL","args":[],"type":{"kind":"SCALAR","name":"String"'
            ',"ofType":null},"isDeprecated":false,"deprecationReason":null},{"n'
            'ame":"fields","args":[{"name":"includeDeprecated","type":{"kind":"'
            'SCALAR","name":"Boolean","ofType":null},"defaultValue":"false"}],"'
            'type":{"kind":"LIST","name":null,"ofType":{"name":null,"kind":"NON'
            '_NULL","ofType":{"name":"__Field","kind":"OBJECT","ofType":null}}}'
            ',"isDeprecated":false,"deprecationReason":null},{"name":"interface'
            's","args":[],"type":{"kind":"LIST","name":null,"ofType":{"name":nu'
            'll,"kind":"NON_NULL","ofType":{"name":"__Type","kind":"OBJECT","of'
            'Type":null}}},"isDeprecated":false,"deprecationReason":null},{"nam'
            'e":"possibleTypes","args":[],"type":{"kind":"LIST","name":null,"of'
            'Type":{"name":null,"kind":"NON_NULL","ofType":{"name":"__Type","ki'
            'nd":"OBJECT","ofType":null}}},"isDeprecated":false,"deprecationRea'
            'son":null},{"name":"enumValues","args":[{"name":"includeDeprecated'
            '","type":{"kind":"SCALAR","name":"Boolean","ofType":null},"default'
            'Value":"false"}],"type":{"kind":"LIST","name":null,"ofType":{"name'
            '":null,"kind":"NON_NULL","ofType":{"name":"__EnumValue","kind":"OB'
            'JECT","ofType":null}}},"isDeprecated":false,"deprecationReason":nu'
            'll},{"name":"inputFields","args":[{"name":"includeDeprecated","typ'
            'e":{"kind":"SCALAR","name":"Boolean","ofType":null},"defaultValue"'
            ':"false"}],"type":{"kind":"LIST","name":null,"ofType":{"name":null'
            ',"kind":"NON_NULL","ofType":{"name":"__InputValue","kind":"OBJECT"'
            ',"ofType":null}}},"isDeprecated":false,"deprecationReason":null},{'
            '"name":"ofType","args":[],"type":{"kind":"OBJECT","name":"__Type",'
            '"ofType":null},"isDeprecated":false,"deprecationReason":null},{"na'
            'me":"isOneOf","args":[],"type":{"kind":"SCALAR","name":"Boolean","'
            'ofType":null},"isDeprecated":false,"deprecationReason":null}],"inp'
            'utFields":null,"interfaces":[],"enumValues":null,"possibleTypes":n'
            'ull},{"kind":"ENUM","name":"__TypeKind","specifiedByURL":null,"fie'
            'lds":null,"inputFields":null,"interfaces":null,"enumValues":[{"nam'
            'e":"SCALAR","isDeprecated":false,"deprecationReason":null},{"name"'
            ':"OBJECT","isDeprecated":false,"deprecationReason":null},{"name":"'
            'INTERFACE","isDeprecated":false,"deprecationReason":null},{"name":'
            '"UNION","isDeprecated":false,"deprecationReason":null},{"name":"EN'
            'UM","isDeprecated":false,"deprecationReason":null},{"name":"INPUT_'
            'OBJECT","isDeprecated":false,"deprecationReason":null},{"name":"LI'
            'ST","isDeprecated":false,"deprecationReason":null},{"name":"NON_NU'
            'LL","isDeprecated":false,"deprecationReason":null}],"possibleTypes'
            '":null},{"kind":"OBJECT","name":"__Field","specifiedByURL":null,"f'
            'ields":[{"name":"name","args":[],"type":{"kind":"NON_NULL","name":'
            'null,"ofType":{"name":"String","kind":"SCALAR","ofType":null}},"is'
            'Deprecated":false,"deprecationReason":null},{"name":"description",'
            '"args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},"'
            'isDeprecated":false,"deprecationReason":null},{"name":"args","args'
            '":[{"name":"includeDeprecated","type":{"kind":"SCALAR","name":"Boo'
            'lean","ofType":null},"defaultValue":"false"}],"type":{"kind":"NON_'
            'NULL","name":null,"ofType":{"name":null,"kind":"LIST","ofType":{"n'
            'ame":null,"kind":"NON_NULL","ofType":{"name":"__InputValue","kind"'
            ':"OBJECT","ofType":null}}}},"isDeprecated":false,"deprecationReaso'
            'n":null},{"name":"type","args":[],"type":{"kind":"NON_NULL","name"'
            ':null,"ofType":{"name":"__Type","kind":"OBJECT","ofType":null}},"i'
            'sDeprecated":false,"deprecationReason":null},{"name":"isDeprecated'
            '","args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"name"'
            ':"Boolean","kind":"SCALAR","ofType":null}},"isDeprecated":false,"d'
            'eprecationReason":null},{"name":"deprecationReason","args":[],"typ'
            'e":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated":'
            'false,"deprecationReason":null}],"inputFields":null,"interfaces":['
            '],"enumValues":null,"possibleTypes":null},{"kind":"OBJECT","name":'
            '"__InputValue","specifiedByURL":null,"fields":[{"name":"name","arg'
            's":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"name":"Stri'
            'ng","kind":"SCALAR","ofType":null}},"isDeprecated":false,"deprecat'
            'ionReason":null},{"name":"description","args":[],"type":{"kind":"S'
            'CALAR","name":"String","ofType":null},"isDeprecated":false,"deprec'
            'ationReason":null},{"name":"type","args":[],"type":{"kind":"NON_NU'
            'LL","name":null,"ofType":{"name":"__Type","kind":"OBJECT","ofType"'
            ':null}},"isDeprecated":false,"deprecationReason":null},{"name":"de'
            'faultValue","args":[],"type":{"kind":"SCALAR","name":"String","ofT'
            'ype":null},"isDeprecated":false,"deprecationReason":null},{"name":'
            '"isDeprecated","args":[],"type":{"kind":"NON_NULL","name":null,"of'
            'Type":{"name":"Boolean","kind":"SCALAR","ofType":null}},"isDepreca'
            'ted":false,"deprecationReason":null},{"name":"deprecationReason","'
            'args":[],"type":{"kind":"SCALAR","name":"String","ofType":null},"i'
            'sDeprecated":false,"deprecationReason":null}],"inputFields":null,"'
            'interfaces":[],"enumValues":null,"possibleTypes":null},{"kind":"OB'
            'JECT","name":"__EnumValue","specifiedByURL":null,"fields":[{"name"'
            ':"name","args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{'
            '"name":"String","kind":"SCALAR","ofType":null}},"isDeprecated":fal'
            'se,"deprecationReason":null},{"name":"description","args":[],"type'
            '":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated":f'
            'alse,"deprecationReason":null},{"name":"isDeprecated","args":[],"t'
            'ype":{"kind":"NON_NULL","name":null,"ofType":{"name":"Boolean","ki'
            'nd":"SCALAR","ofType":null}},"isDeprecated":false,"deprecationReas'
            'on":null},{"name":"deprecationReason","args":[],"type":{"kind":"SC'
            'ALAR","name":"String","ofType":null},"isDeprecated":false,"depreca'
            'tionReason":null}],"inputFields":null,"interfaces":[],"enumValues"'
            ':null,"possibleTypes":null},{"kind":"OBJECT","name":"__Directive",'
            '"specifiedByURL":null,"fields":[{"name":"name","args":[],"type":{"'
            'kind":"NON_NULL","name":null,"ofType":{"name":"String","kind":"SCA'
            'LAR","ofType":null}},"isDeprecated":false,"deprecationReason":null'
            '},{"name":"description","args":[],"type":{"kind":"SCALAR","name":"'
            'String","ofType":null},"isDeprecated":false,"deprecationReason":nu'
            'll},{"name":"isRepeatable","args":[],"type":{"kind":"NON_NULL","na'
            'me":null,"ofType":{"name":"Boolean","kind":"SCALAR","ofType":null}'
            '},"isDeprecated":false,"deprecationReason":null},{"name":"location'
            's","args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"name'
            '":null,"kind":"LIST","ofType":{"name":null,"kind":"NON_NULL","ofTy'
            'pe":{"name":"__DirectiveLocation","kind":"ENUM","ofType":null}}}},'
            '"isDeprecated":false,"deprecationReason":null},{"name":"args","arg'
            's":[{"name":"includeDeprecated","type":{"kind":"SCALAR","name":"Bo'
            'olean","ofType":null},"defaultValue":"false"}],"type":{"kind":"NON'
            '_NULL","name":null,"ofType":{"name":null,"kind":"LIST","ofType":{"'
            'name":null,"kind":"NON_NULL","ofType":{"name":"__InputValue","kind'
            '":"OBJECT","ofType":null}}}},"isDeprecated":false,"deprecationReas'
            'on":null},{"name":"isDeprecated","args":[],"type":{"kind":"NON_NUL'
            'L","name":null,"ofType":{"name":"Boolean","kind":"SCALAR","ofType"'
            ':null}},"isDeprecated":false,"deprecationReason":null},{"name":"de'
            'precationReason","args":[],"type":{"kind":"SCALAR","name":"String"'
            ',"ofType":null},"isDeprecated":false,"deprecationReason":null}],"i'
            'nputFields":null,"interfaces":[],"enumValues":null,"possibleTypes"'
            ':null},{"kind":"ENUM","name":"__DirectiveLocation","specifiedByURL'
            '":null,"fields":null,"inputFields":null,"interfaces":null,"enumVal'
            'ues":[{"name":"QUERY","isDeprecated":false,"deprecationReason":nul'
            'l},{"name":"MUTATION","isDeprecated":false,"deprecationReason":nul'
            'l},{"name":"SUBSCRIPTION","isDeprecated":false,"deprecationReason"'
            ':null},{"name":"FIELD","isDeprecated":false,"deprecationReason":nu'
            'll},{"name":"FRAGMENT_DEFINITION","isDeprecated":false,"deprecatio'
            'nReason":null},{"name":"FRAGMENT_SPREAD","isDeprecated":false,"dep'
            'recationReason":null},{"name":"INLINE_FRAGMENT","isDeprecated":fal'
            'se,"deprecationReason":null},{"name":"VARIABLE_DEFINITION","isDepr'
            'ecated":false,"deprecationReason":null},{"name":"SCHEMA","isDeprec'
            'ated":false,"deprecationReason":null},{"name":"SCALAR","isDeprecat'
            'ed":false,"deprecationReason":null},{"name":"OBJECT","isDeprecated'
            '":false,"deprecationReason":null},{"name":"FIELD_DEFINITION","isDe'
            'precated":false,"deprecationReason":null},{"name":"ARGUMENT_DEFINI'
            'TION","isDeprecated":false,"deprecationReason":null},{"name":"INTE'
            'RFACE","isDeprecated":false,"deprecationReason":null},{"name":"UNI'
            'ON","isDeprecated":false,"deprecationReason":null},{"name":"ENUM",'
            '"isDeprecated":false,"deprecationReason":null},{"name":"ENUM_VALUE'
            '","isDeprecated":false,"deprecationReason":null},{"name":"INPUT_OB'
            'JECT","isDeprecated":false,"deprecationReason":null},{"name":"INPU'
            'T_FIELD_DEFINITION","isDeprecated":false,"deprecationReason":null}'
            ',{"name":"DIRECTIVE_DEFINITION","isDeprecated":false,"deprecationR'
            'eason":null}],"possibleTypes":null}],"directives":[{"name":"includ'
            'e","isRepeatable":false,"locations":["FIELD","FRAGMENT_SPREAD","IN'
            'LINE_FRAGMENT"],"args":[{"name":"if","type":{"kind":"NON_NULL","na'
            'me":null,"ofType":{"name":"Boolean","kind":"SCALAR","ofType":null}'
            '},"defaultValue":null}]},{"name":"skip","isRepeatable":false,"loca'
            'tions":["FIELD","FRAGMENT_SPREAD","INLINE_FRAGMENT"],"args":[{"nam'
            'e":"if","type":{"kind":"NON_NULL","name":null,"ofType":{"name":"Bo'
            'olean","kind":"SCALAR","ofType":null}},"defaultValue":null}]},{"na'
            'me":"deprecated","isRepeatable":false,"locations":["FIELD_DEFINITI'
            'ON","ARGUMENT_DEFINITION","INPUT_FIELD_DEFINITION","ENUM_VALUE","D'
            'IRECTIVE_DEFINITION"],"args":[{"name":"reason","type":{"kind":"SCA'
            'LAR","name":"String","ofType":null},"defaultValue":"\\"No longer s'
            'upported\\""}]},{"name":"specifiedBy","isRepeatable":false,"locati'
            'ons":["SCALAR"],"args":[{"name":"url","type":{"kind":"NON_NULL","n'
            'ame":null,"ofType":{"name":"String","kind":"SCALAR","ofType":null}'
            '},"defaultValue":null}]},{"name":"oneOf","isRepeatable":false,"loc'
            'ations":["INPUT_OBJECT"],"args":[]}]}}}'
        ),
    )


def test_introspects_on_input_object() raises:
    check(
        """input SomeInputObject {
  a: String = "tes\\t de\\fault"
  b: [String]
  c: String = null
}

type Query {
  someField(someArg: SomeInputObject): String
}""",
        """
      {
        __type(name: "SomeInputObject") {
          kind
          name
          inputFields {
            name
            type { ...TypeRef }
            defaultValue
          }
        }
      }

      fragment TypeRef on __Type {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
            }
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"kind":"INPUT_OBJECT","name":"SomeInputObject",'
            '"inputFields":[{"name":"a","type":{"kind":"SCALAR","name":"String"'
            ',"ofType":null},"defaultValue":"\\"tes\\\\t de\\\\fault\\""},{"nam'
            'e":"b","type":{"kind":"LIST","name":null,"ofType":{"kind":"SCALAR"'
            ',"name":"String","ofType":null}},"defaultValue":null},{"name":"c",'
            '"type":{"kind":"SCALAR","name":"String","ofType":null},"defaultVal'
            'ue":"null"}]}}}'
        ),
    )


def test_introspects_any_default_value() raises:
    check(
        """input InputObjectWithDefaultValues {
  a: String = "Emoji: 😀"
  b: Complex = {x: ["abc"], y: 123}
}

input Complex {
  x: [String]
  y: Int
}

type Query {
  someField(someArg: InputObjectWithDefaultValues): String
}""",
        """
      {
        __type(name: "InputObjectWithDefaultValues") {
          inputFields {
            name
            defaultValue
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"inputFields":[{"name":"a","defaultValue":"\\"E'
            'moji: 😀\\""},{"name":"b","defaultValue":"{x: [\\"abc\\"], y: 123}'
            '"}]}}}'
        ),
    )


def test_supports_the_type_root_field() raises:
    check(
        """type Query {
  someField: String
}""",
        """
      {
        __type(name: "Query") {
          name
        }
      }
    """,
        "",
        '{"data":{"__type":{"name":"Query"}}}',
    )


def test_identifies_deprecated_fields() raises:
    check(
        """type Query {
  nonDeprecated: String
  deprecated: String @deprecated(reason: "Removed in 1.0")
  deprecatedWithEmptyReason: String @deprecated(reason: "")
}""",
        """
      {
        __type(name: "Query") {
          fields(includeDeprecated: true) {
            name
            isDeprecated,
            deprecationReason
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"fields":[{"name":"nonDeprecated","isDeprecated'
            '":false,"deprecationReason":null},{"name":"deprecated","isDeprecat'
            'ed":true,"deprecationReason":"Removed in 1.0"},{"name":"deprecated'
            'WithEmptyReason","isDeprecated":true,"deprecationReason":""}]}}}'
        ),
    )


def test_respects_the_includedeprecated_parameter_for_fields() raises:
    check(
        """type Query {
  nonDeprecated: String
  deprecated: String @deprecated(reason: "Removed in 1.0")
}""",
        """
      {
        __type(name: "Query") {
          trueFields: fields(includeDeprecated: true) {
            name
          }
          falseFields: fields(includeDeprecated: false) {
            name
          }
          omittedFields: fields {
            name
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"trueFields":[{"name":"nonDeprecated"},{"name":'
            '"deprecated"}],"falseFields":[{"name":"nonDeprecated"}],"omittedFi'
            'elds":[{"name":"nonDeprecated"}]}}}'
        ),
    )


def test_identifies_deprecated_args() raises:
    check(
        """type Query {
  someField(nonDeprecated: String, deprecated: String @deprecated(reason: "Removed in 1.0"), deprecatedWithEmptyReason: String @deprecated(reason: "")): String
}""",
        """
      {
        __type(name: "Query") {
          fields {
            args(includeDeprecated: true) {
              name
              isDeprecated,
              deprecationReason
            }
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"fields":[{"args":[{"name":"nonDeprecated","isD'
            'eprecated":false,"deprecationReason":null},{"name":"deprecated","i'
            'sDeprecated":true,"deprecationReason":"Removed in 1.0"},{"name":"d'
            'eprecatedWithEmptyReason","isDeprecated":true,"deprecationReason":'
            '""}]}]}}}'
        ),
    )


def test_respects_the_includedeprecated_parameter_for_args() raises:
    check(
        """type Query {
  someField(nonDeprecated: String, deprecated: String @deprecated(reason: "Removed in 1.0")): String
}""",
        """
      {
        __type(name: "Query") {
          fields {
            trueArgs: args(includeDeprecated: true) {
              name
            }
            falseArgs: args(includeDeprecated: false) {
              name
            }
            omittedArgs: args {
              name
            }
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"fields":[{"trueArgs":[{"name":"nonDeprecated"}'
            ',{"name":"deprecated"}],"falseArgs":[{"name":"nonDeprecated"}],"om'
            'ittedArgs":[{"name":"nonDeprecated"}]}]}}}'
        ),
    )


def test_identifies_deprecated_enum_values() raises:
    check(
        """enum SomeEnum {
  NON_DEPRECATED
  DEPRECATED @deprecated(reason: "Removed in 1.0")
  ALSO_NON_DEPRECATED
}

type Query {
  someField(someArg: SomeEnum): String
}""",
        """
      {
        __type(name: "SomeEnum") {
          enumValues(includeDeprecated: true) {
            name
            isDeprecated,
            deprecationReason
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"enumValues":[{"name":"NON_DEPRECATED","isDepre'
            'cated":false,"deprecationReason":null},{"name":"DEPRECATED","isDep'
            'recated":true,"deprecationReason":"Removed in 1.0"},{"name":"ALSO_'
            'NON_DEPRECATED","isDeprecated":false,"deprecationReason":null}]}}}'
        ),
    )


def test_respects_the_includedeprecated_parameter_for_enum_values() raises:
    check(
        """enum SomeEnum {
  NON_DEPRECATED
  DEPRECATED @deprecated(reason: "Removed in 1.0")
  DEPRECATED_WITH_EMPTY_REASON @deprecated(reason: "")
  ALSO_NON_DEPRECATED
}

type Query {
  someField(someArg: SomeEnum): String
}""",
        """
      {
        __type(name: "SomeEnum") {
          trueValues: enumValues(includeDeprecated: true) {
            name
          }
          falseValues: enumValues(includeDeprecated: false) {
            name
          }
          omittedValues: enumValues {
            name
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"trueValues":[{"name":"NON_DEPRECATED"},{"name"'
            ':"DEPRECATED"},{"name":"DEPRECATED_WITH_EMPTY_REASON"},{"name":"AL'
            'SO_NON_DEPRECATED"}],"falseValues":[{"name":"NON_DEPRECATED"},{"na'
            'me":"ALSO_NON_DEPRECATED"}],"omittedValues":[{"name":"NON_DEPRECAT'
            'ED"},{"name":"ALSO_NON_DEPRECATED"}]}}}'
        ),
    )


def test_identifies_deprecated_for_input_fields() raises:
    check(
        """input SomeInputObject {
  nonDeprecated: String
  deprecated: String @deprecated(reason: "Removed in 1.0")
  deprecatedWithEmptyReason: String @deprecated(reason: "")
}

type Query {
  someField(someArg: SomeInputObject): String
}""",
        """
      {
        __type(name: "SomeInputObject") {
          inputFields(includeDeprecated: true) {
            name
            isDeprecated,
            deprecationReason
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"inputFields":[{"name":"nonDeprecated","isDepre'
            'cated":false,"deprecationReason":null},{"name":"deprecated","isDep'
            'recated":true,"deprecationReason":"Removed in 1.0"},{"name":"depre'
            'catedWithEmptyReason","isDeprecated":true,"deprecationReason":""}]'
            "}}}"
        ),
    )


def test_respects_the_includedeprecated_parameter_for_input_fields() raises:
    check(
        """input SomeInputObject {
  nonDeprecated: String
  deprecated: String @deprecated(reason: "Removed in 1.0")
}

type Query {
  someField(someArg: SomeInputObject): String
}""",
        """
      {
        __type(name: "SomeInputObject") {
          trueFields: inputFields(includeDeprecated: true) {
            name
          }
          falseFields: inputFields(includeDeprecated: false) {
            name
          }
          omittedFields: inputFields {
            name
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__type":{"trueFields":[{"name":"nonDeprecated"},{"name":'
            '"deprecated"}],"falseFields":[{"name":"nonDeprecated"}],"omittedFi'
            'elds":[{"name":"nonDeprecated"}]}}}'
        ),
    )


def test_identifies_oneof_for_input_objects() raises:
    check(
        """input SomeInputObject @oneOf {
  a: String
}

input AnotherInputObject {
  a: String
  b: String
}

type Query {
  someField(someArg: SomeInputObject): String
  anotherField(anotherArg: AnotherInputObject): String
}""",
        """
      {
        oneOfInputObject: __type(name: "SomeInputObject") {
          isOneOf
        }
        inputObject: __type(name: "AnotherInputObject") {
          isOneOf
        }
      }
    """,
        "",
        (
            '{"data":{"oneOfInputObject":{"isOneOf":true},"inputObject":{"isOne'
            'Of":false}}}'
        ),
    )


def test_returns_null_for_oneof_for_other_types() raises:
    check(
        """type SomeObject implements SomeInterface {
  fieldA: String
}

enum SomeEnum {
  SomeObject
}

interface SomeInterface {
  fieldA: String
}

union SomeUnion = SomeObject

type Query {
  someField(enum: SomeEnum): SomeUnion
  anotherField(enum: SomeEnum): SomeInterface
}""",
        """
      {
        object: __type(name: "SomeObject") {
          isOneOf
        }
        enum: __type(name: "SomeEnum") {
          isOneOf
        }
        interface: __type(name: "SomeInterface") {
          isOneOf
        }
        scalar: __type(name: "String") {
          isOneOf
        }
        union: __type(name: "SomeUnion") {
          isOneOf
        }
      }
    """,
        "",
        (
            '{"data":{"object":{"isOneOf":null},"enum":{"isOneOf":null},"interf'
            'ace":{"isOneOf":null},"scalar":{"isOneOf":null},"union":{"isOneOf"'
            ":null}}}"
        ),
    )


def test_fails_as_expected_on_the_type_root_field_without_an_arg() raises:
    check(
        """type Query {
  someField: String
}""",
        """
      {
        __type {
          name
        }
      }
    """,
        "",
        (
            '{"errors":[{"message":"Argument \\"name\\" of required type \\"Str'
            'ing!\\" was not provided.","locations":[{"line":3,"column":9}],"pa'
            'th":["__type"]}],"data":{"__type":null}}'
        ),
    )


def test_exposes_descriptions() raises:
    check(
        '''"""Schema description"""
schema {
  query: SomeObject
}

"""Enum description"""
enum SomeEnum {
  """Value description"""
  VALUE
}

"""Object description"""
type SomeObject {
  """Field description"""
  someField(arg: SomeEnum): String
}''',
        """
      {
        Schema: __schema { description }
        SomeObject: __type(name: "SomeObject") {
          description,
          fields {
            name
            description
          }
        }
        SomeEnum: __type(name: "SomeEnum") {
          description
          enumValues {
            name
            description
          }
        }
      }
    """,
        "",
        (
            '{"data":{"Schema":{"description":"Schema description"},"SomeObject'
            '":{"description":"Object description","fields":[{"name":"someField'
            '","description":"Field description"}]},"SomeEnum":{"description":"'
            'Enum description","enumValues":[{"name":"VALUE","description":"Val'
            'ue description"}]}}}'
        ),
    )


def test_executes_an_introspection_query_without_calling_global_resolvers() raises:
    check(
        """type Query {
  someField: String
}""",
        """
    query IntrospectionQuery {
      __schema {
        description
        queryType { name kind }
        mutationType { name kind }
        subscriptionType { name kind }
        types {
          ...FullType
        }
        directives {
          name
          description
          isRepeatable
          
          
          locations
          args {
            ...InputValue
          }
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      description
      specifiedByURL
      
      fields(includeDeprecated: true) {
        name
        description
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
      defaultValue
      
      
    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        name
        kind
        ofType {
          name
          kind
          ofType {
            name
            kind
            ofType {
              name
              kind
              ofType {
                name
                kind
                ofType {
                  name
                  kind
                  ofType {
                    name
                    kind
                    ofType {
                      name
                      kind
                      ofType {
                        name
                        kind
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  """,
        "",
        (
            '{"data":{"__schema":{"description":null,"queryType":{"name":"Query'
            '","kind":"OBJECT"},"mutationType":null,"subscriptionType":null,"ty'
            'pes":[{"kind":"OBJECT","name":"Query","description":null,"specifie'
            'dByURL":null,"fields":[{"name":"someField","description":null,"arg'
            's":[],"type":{"kind":"SCALAR","name":"String","ofType":null},"isDe'
            'precated":false,"deprecationReason":null}],"inputFields":null,"int'
            'erfaces":[],"enumValues":null,"possibleTypes":null},{"kind":"SCALA'
            'R","name":"String","description":"The `String` scalar type represe'
            "nts textual data, represented as UTF-8 character sequences. The St"
            "ring type is most often used by GraphQL to represent free-form hum"
            'an-readable text.","specifiedByURL":null,"fields":null,"inputField'
            's":null,"interfaces":null,"enumValues":null,"possibleTypes":null},'
            '{"kind":"SCALAR","name":"Boolean","description":"The `Boolean` sca'
            'lar type represents `true` or `false`.","specifiedByURL":null,"fie'
            'lds":null,"inputFields":null,"interfaces":null,"enumValues":null,"'
            'possibleTypes":null},{"kind":"OBJECT","name":"__Schema","descripti'
            'on":"A GraphQL Schema defines the capabilities of a GraphQL server'
            ". It exposes all available types and directives on the server, as "
            "well as the entry points for query, mutation, and subscription ope"
            'rations.","specifiedByURL":null,"fields":[{"name":"description","d'
            'escription":null,"args":[],"type":{"kind":"SCALAR","name":"String"'
            ',"ofType":null},"isDeprecated":false,"deprecationReason":null},{"n'
            'ame":"types","description":"A list of all types supported by this '
            'server.","args":[],"type":{"kind":"NON_NULL","name":null,"ofType":'
            '{"name":null,"kind":"LIST","ofType":{"name":null,"kind":"NON_NULL"'
            ',"ofType":{"name":"__Type","kind":"OBJECT","ofType":null}}}},"isDe'
            'precated":false,"deprecationReason":null},{"name":"queryType","des'
            'cription":"The type that query operations will be rooted at.","arg'
            's":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"name":"__Ty'
            'pe","kind":"OBJECT","ofType":null}},"isDeprecated":false,"deprecat'
            'ionReason":null},{"name":"mutationType","description":"If this ser'
            "ver supports mutation, the type that mutation operations will be r"
            'ooted at.","args":[],"type":{"kind":"OBJECT","name":"__Type","ofTy'
            'pe":null},"isDeprecated":false,"deprecationReason":null},{"name":"'
            'subscriptionType","description":"If this server support subscripti'
            'on, the type that subscription operations will be rooted at.","arg'
            's":[],"type":{"kind":"OBJECT","name":"__Type","ofType":null},"isDe'
            'precated":false,"deprecationReason":null},{"name":"directives","de'
            'scription":"A list of all directives supported by this server.","a'
            'rgs":[{"name":"includeDeprecated","description":null,"type":{"kind'
            '":"NON_NULL","name":null,"ofType":{"name":"Boolean","kind":"SCALAR'
            '","ofType":null}},"defaultValue":"false"}],"type":{"kind":"NON_NUL'
            'L","name":null,"ofType":{"name":null,"kind":"LIST","ofType":{"name'
            '":null,"kind":"NON_NULL","ofType":{"name":"__Directive","kind":"OB'
            'JECT","ofType":null}}}},"isDeprecated":false,"deprecationReason":n'
            'ull}],"inputFields":null,"interfaces":[],"enumValues":null,"possib'
            'leTypes":null},{"kind":"OBJECT","name":"__Type","description":"The'
            " fundamental unit of any GraphQL Schema is the type. There are man"
            "y kinds of types in GraphQL as represented by the `__TypeKind` enu"
            "m.\\n\\nDepending on the kind of a type, certain fields describe i"
            "nformation about that type. Scalar types provide no information be"
            "yond a name, description and optional `specifiedByURL`, while Enum"
            " types provide their values. Object and Interface types provide th"
            "e fields they describe. Abstract types, Union and Interface, provi"
            "de the Object types possible at runtime. List and NonNull types co"
            'mpose other types.","specifiedByURL":null,"fields":[{"name":"kind"'
            ',"description":null,"args":[],"type":{"kind":"NON_NULL","name":nul'
            'l,"ofType":{"name":"__TypeKind","kind":"ENUM","ofType":null}},"isD'
            'eprecated":false,"deprecationReason":null},{"name":"name","descrip'
            'tion":null,"args":[],"type":{"kind":"SCALAR","name":"String","ofTy'
            'pe":null},"isDeprecated":false,"deprecationReason":null},{"name":"'
            'description","description":null,"args":[],"type":{"kind":"SCALAR",'
            '"name":"String","ofType":null},"isDeprecated":false,"deprecationRe'
            'ason":null},{"name":"specifiedByURL","description":null,"args":[],'
            '"type":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecat'
            'ed":false,"deprecationReason":null},{"name":"fields","description"'
            ':null,"args":[{"name":"includeDeprecated","description":null,"type'
            '":{"kind":"SCALAR","name":"Boolean","ofType":null},"defaultValue":'
            '"false"}],"type":{"kind":"LIST","name":null,"ofType":{"name":null,'
            '"kind":"NON_NULL","ofType":{"name":"__Field","kind":"OBJECT","ofTy'
            'pe":null}}},"isDeprecated":false,"deprecationReason":null},{"name"'
            ':"interfaces","description":null,"args":[],"type":{"kind":"LIST","'
            'name":null,"ofType":{"name":null,"kind":"NON_NULL","ofType":{"name'
            '":"__Type","kind":"OBJECT","ofType":null}}},"isDeprecated":false,"'
            'deprecationReason":null},{"name":"possibleTypes","description":nul'
            'l,"args":[],"type":{"kind":"LIST","name":null,"ofType":{"name":nul'
            'l,"kind":"NON_NULL","ofType":{"name":"__Type","kind":"OBJECT","ofT'
            'ype":null}}},"isDeprecated":false,"deprecationReason":null},{"name'
            '":"enumValues","description":null,"args":[{"name":"includeDeprecat'
            'ed","description":null,"type":{"kind":"SCALAR","name":"Boolean","o'
            'fType":null},"defaultValue":"false"}],"type":{"kind":"LIST","name"'
            ':null,"ofType":{"name":null,"kind":"NON_NULL","ofType":{"name":"__'
            'EnumValue","kind":"OBJECT","ofType":null}}},"isDeprecated":false,"'
            'deprecationReason":null},{"name":"inputFields","description":null,'
            '"args":[{"name":"includeDeprecated","description":null,"type":{"ki'
            'nd":"SCALAR","name":"Boolean","ofType":null},"defaultValue":"false'
            '"}],"type":{"kind":"LIST","name":null,"ofType":{"name":null,"kind"'
            ':"NON_NULL","ofType":{"name":"__InputValue","kind":"OBJECT","ofTyp'
            'e":null}}},"isDeprecated":false,"deprecationReason":null},{"name":'
            '"ofType","description":null,"args":[],"type":{"kind":"OBJECT","nam'
            'e":"__Type","ofType":null},"isDeprecated":false,"deprecationReason'
            '":null},{"name":"isOneOf","description":null,"args":[],"type":{"ki'
            'nd":"SCALAR","name":"Boolean","ofType":null},"isDeprecated":false,'
            '"deprecationReason":null}],"inputFields":null,"interfaces":[],"enu'
            'mValues":null,"possibleTypes":null},{"kind":"ENUM","name":"__TypeK'
            'ind","description":"An enum describing what kind of type a given `'
            '__Type` is.","specifiedByURL":null,"fields":null,"inputFields":nul'
            'l,"interfaces":null,"enumValues":[{"name":"SCALAR","description":"'
            'Indicates this type is a scalar.","isDeprecated":false,"deprecatio'
            'nReason":null},{"name":"OBJECT","description":"Indicates this type'
            ' is an object. `fields` and `interfaces` are valid fields.","isDep'
            'recated":false,"deprecationReason":null},{"name":"INTERFACE","desc'
            'ription":"Indicates this type is an interface. `fields`, `interfac'
            'es`, and `possibleTypes` are valid fields.","isDeprecated":false,"'
            'deprecationReason":null},{"name":"UNION","description":"Indicates '
            'this type is a union. `possibleTypes` is a valid field.","isDeprec'
            'ated":false,"deprecationReason":null},{"name":"ENUM","description"'
            ':"Indicates this type is an enum. `enumValues` is a valid field.",'
            '"isDeprecated":false,"deprecationReason":null},{"name":"INPUT_OBJE'
            'CT","description":"Indicates this type is an input object. `inputF'
            'ields` is a valid field.","isDeprecated":false,"deprecationReason"'
            ':null},{"name":"LIST","description":"Indicates this type is a list'
            '. `ofType` is a valid field.","isDeprecated":false,"deprecationRea'
            'son":null},{"name":"NON_NULL","description":"Indicates this type i'
            's a non-null. `ofType` is a valid field.","isDeprecated":false,"de'
            'precationReason":null}],"possibleTypes":null},{"kind":"OBJECT","na'
            'me":"__Field","description":"Object and Interface types are descri'
            "bed by a list of Fields, each of which has a name, potentially a l"
            'ist of arguments, and a return type.","specifiedByURL":null,"field'
            's":[{"name":"name","description":null,"args":[],"type":{"kind":"NO'
            'N_NULL","name":null,"ofType":{"name":"String","kind":"SCALAR","ofT'
            'ype":null}},"isDeprecated":false,"deprecationReason":null},{"name"'
            ':"description","description":null,"args":[],"type":{"kind":"SCALAR'
            '","name":"String","ofType":null},"isDeprecated":false,"deprecation'
            'Reason":null},{"name":"args","description":null,"args":[{"name":"i'
            'ncludeDeprecated","description":null,"type":{"kind":"SCALAR","name'
            '":"Boolean","ofType":null},"defaultValue":"false"}],"type":{"kind"'
            ':"NON_NULL","name":null,"ofType":{"name":null,"kind":"LIST","ofTyp'
            'e":{"name":null,"kind":"NON_NULL","ofType":{"name":"__InputValue",'
            '"kind":"OBJECT","ofType":null}}}},"isDeprecated":false,"deprecatio'
            'nReason":null},{"name":"type","description":null,"args":[],"type":'
            '{"kind":"NON_NULL","name":null,"ofType":{"name":"__Type","kind":"O'
            'BJECT","ofType":null}},"isDeprecated":false,"deprecationReason":nu'
            'll},{"name":"isDeprecated","description":null,"args":[],"type":{"k'
            'ind":"NON_NULL","name":null,"ofType":{"name":"Boolean","kind":"SCA'
            'LAR","ofType":null}},"isDeprecated":false,"deprecationReason":null'
            '},{"name":"deprecationReason","description":null,"args":[],"type":'
            '{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated":fal'
            'se,"deprecationReason":null}],"inputFields":null,"interfaces":[],"'
            'enumValues":null,"possibleTypes":null},{"kind":"OBJECT","name":"__'
            'InputValue","description":"Arguments provided to Fields or Directi'
            "ves and the input fields of an InputObject are represented as Inpu"
            "t Values which describe their type and optionally a default value."
            '","specifiedByURL":null,"fields":[{"name":"name","description":nul'
            'l,"args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"name"'
            ':"String","kind":"SCALAR","ofType":null}},"isDeprecated":false,"de'
            'precationReason":null},{"name":"description","description":null,"a'
            'rgs":[],"type":{"kind":"SCALAR","name":"String","ofType":null},"is'
            'Deprecated":false,"deprecationReason":null},{"name":"type","descri'
            'ption":null,"args":[],"type":{"kind":"NON_NULL","name":null,"ofTyp'
            'e":{"name":"__Type","kind":"OBJECT","ofType":null}},"isDeprecated"'
            ':false,"deprecationReason":null},{"name":"defaultValue","descripti'
            'on":"A GraphQL-formatted string representing the default value for'
            ' this input value.","args":[],"type":{"kind":"SCALAR","name":"Stri'
            'ng","ofType":null},"isDeprecated":false,"deprecationReason":null},'
            '{"name":"isDeprecated","description":null,"args":[],"type":{"kind"'
            ':"NON_NULL","name":null,"ofType":{"name":"Boolean","kind":"SCALAR"'
            ',"ofType":null}},"isDeprecated":false,"deprecationReason":null},{"'
            'name":"deprecationReason","description":null,"args":[],"type":{"ki'
            'nd":"SCALAR","name":"String","ofType":null},"isDeprecated":false,"'
            'deprecationReason":null}],"inputFields":null,"interfaces":[],"enum'
            'Values":null,"possibleTypes":null},{"kind":"OBJECT","name":"__Enum'
            'Value","description":"One possible value for a given Enum. Enum va'
            "lues are unique values, not a placeholder for a string or numeric "
            "value. However an Enum value is returned in a JSON response as a s"
            'tring.","specifiedByURL":null,"fields":[{"name":"name","descriptio'
            'n":null,"args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{'
            '"name":"String","kind":"SCALAR","ofType":null}},"isDeprecated":fal'
            'se,"deprecationReason":null},{"name":"description","description":n'
            'ull,"args":[],"type":{"kind":"SCALAR","name":"String","ofType":nul'
            'l},"isDeprecated":false,"deprecationReason":null},{"name":"isDepre'
            'cated","description":null,"args":[],"type":{"kind":"NON_NULL","nam'
            'e":null,"ofType":{"name":"Boolean","kind":"SCALAR","ofType":null}}'
            ',"isDeprecated":false,"deprecationReason":null},{"name":"deprecati'
            'onReason","description":null,"args":[],"type":{"kind":"SCALAR","na'
            'me":"String","ofType":null},"isDeprecated":false,"deprecationReaso'
            'n":null}],"inputFields":null,"interfaces":[],"enumValues":null,"po'
            'ssibleTypes":null},{"kind":"OBJECT","name":"__Directive","descript'
            'ion":"A Directive provides a way to describe alternate runtime exe'
            "cution and type validation behavior in a GraphQL document.\\n\\nIn"
            " some cases, you need to provide options to alter GraphQL's execu"
            "tion behavior in ways field arguments will not suffice, such as co"
            "nditionally including or skipping a field. Directives provide this"
            ' by describing additional information to the executor.","specified'
            'ByURL":null,"fields":[{"name":"name","description":null,"args":[],'
            '"type":{"kind":"NON_NULL","name":null,"ofType":{"name":"String","k'
            'ind":"SCALAR","ofType":null}},"isDeprecated":false,"deprecationRea'
            'son":null},{"name":"description","description":null,"args":[],"typ'
            'e":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated":'
            'false,"deprecationReason":null},{"name":"isRepeatable","descriptio'
            'n":null,"args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{'
            '"name":"Boolean","kind":"SCALAR","ofType":null}},"isDeprecated":fa'
            'lse,"deprecationReason":null},{"name":"locations","description":nu'
            'll,"args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"name'
            '":null,"kind":"LIST","ofType":{"name":null,"kind":"NON_NULL","ofTy'
            'pe":{"name":"__DirectiveLocation","kind":"ENUM","ofType":null}}}},'
            '"isDeprecated":false,"deprecationReason":null},{"name":"args","des'
            'cription":null,"args":[{"name":"includeDeprecated","description":n'
            'ull,"type":{"kind":"SCALAR","name":"Boolean","ofType":null},"defau'
            'ltValue":"false"}],"type":{"kind":"NON_NULL","name":null,"ofType":'
            '{"name":null,"kind":"LIST","ofType":{"name":null,"kind":"NON_NULL"'
            ',"ofType":{"name":"__InputValue","kind":"OBJECT","ofType":null}}}}'
            ',"isDeprecated":false,"deprecationReason":null},{"name":"isDepreca'
            'ted","description":null,"args":[],"type":{"kind":"NON_NULL","name"'
            ':null,"ofType":{"name":"Boolean","kind":"SCALAR","ofType":null}},"'
            'isDeprecated":false,"deprecationReason":null},{"name":"deprecation'
            'Reason","description":null,"args":[],"type":{"kind":"SCALAR","name'
            '":"String","ofType":null},"isDeprecated":false,"deprecationReason"'
            ':null}],"inputFields":null,"interfaces":[],"enumValues":null,"poss'
            'ibleTypes":null},{"kind":"ENUM","name":"__DirectiveLocation","desc'
            'ription":"A Directive can be adjacent to many parts of the GraphQL'
            " language, a __DirectiveLocation describes one such possible adjac"
            'encies.","specifiedByURL":null,"fields":null,"inputFields":null,"i'
            'nterfaces":null,"enumValues":[{"name":"QUERY","description":"Locat'
            'ion adjacent to a query operation.","isDeprecated":false,"deprecat'
            'ionReason":null},{"name":"MUTATION","description":"Location adjace'
            'nt to a mutation operation.","isDeprecated":false,"deprecationReas'
            'on":null},{"name":"SUBSCRIPTION","description":"Location adjacent '
            'to a subscription operation.","isDeprecated":false,"deprecationRea'
            'son":null},{"name":"FIELD","description":"Location adjacent to a f'
            'ield.","isDeprecated":false,"deprecationReason":null},{"name":"FRA'
            'GMENT_DEFINITION","description":"Location adjacent to a fragment d'
            'efinition.","isDeprecated":false,"deprecationReason":null},{"name"'
            ':"FRAGMENT_SPREAD","description":"Location adjacent to a fragment '
            'spread.","isDeprecated":false,"deprecationReason":null},{"name":"I'
            'NLINE_FRAGMENT","description":"Location adjacent to an inline frag'
            'ment.","isDeprecated":false,"deprecationReason":null},{"name":"VAR'
            'IABLE_DEFINITION","description":"Location adjacent to a variable d'
            'efinition.","isDeprecated":false,"deprecationReason":null},{"name"'
            ':"SCHEMA","description":"Location adjacent to a schema definition.'
            '","isDeprecated":false,"deprecationReason":null},{"name":"SCALAR",'
            '"description":"Location adjacent to a scalar definition.","isDepre'
            'cated":false,"deprecationReason":null},{"name":"OBJECT","descripti'
            'on":"Location adjacent to an object type definition.","isDeprecate'
            'd":false,"deprecationReason":null},{"name":"FIELD_DEFINITION","des'
            'cription":"Location adjacent to a field definition.","isDeprecated'
            '":false,"deprecationReason":null},{"name":"ARGUMENT_DEFINITION","d'
            'escription":"Location adjacent to an argument definition.","isDepr'
            'ecated":false,"deprecationReason":null},{"name":"INTERFACE","descr'
            'iption":"Location adjacent to an interface definition.","isDepreca'
            'ted":false,"deprecationReason":null},{"name":"UNION","description"'
            ':"Location adjacent to a union definition.","isDeprecated":false,"'
            'deprecationReason":null},{"name":"ENUM","description":"Location ad'
            'jacent to an enum definition.","isDeprecated":false,"deprecationRe'
            'ason":null},{"name":"ENUM_VALUE","description":"Location adjacent '
            'to an enum value definition.","isDeprecated":false,"deprecationRea'
            'son":null},{"name":"INPUT_OBJECT","description":"Location adjacent'
            ' to an input object type definition.","isDeprecated":false,"deprec'
            'ationReason":null},{"name":"INPUT_FIELD_DEFINITION","description":'
            '"Location adjacent to an input object field definition.","isDeprec'
            'ated":false,"deprecationReason":null},{"name":"DIRECTIVE_DEFINITIO'
            'N","description":"Location adjacent to a directive definition.","i'
            'sDeprecated":false,"deprecationReason":null}],"possibleTypes":null'
            '}],"directives":[{"name":"include","description":"Directs the exec'
            "utor to include this field or fragment only when the `if` argument"
            ' is true.","isRepeatable":false,"locations":["FIELD","FRAGMENT_SPR'
            'EAD","INLINE_FRAGMENT"],"args":[{"name":"if","description":"Includ'
            'ed when true.","type":{"kind":"NON_NULL","name":null,"ofType":{"na'
            'me":"Boolean","kind":"SCALAR","ofType":null}},"defaultValue":null}'
            ']},{"name":"skip","description":"Directs the executor to skip this'
            ' field or fragment when the `if` argument is true.","isRepeatable"'
            ':false,"locations":["FIELD","FRAGMENT_SPREAD","INLINE_FRAGMENT"],"'
            'args":[{"name":"if","description":"Skipped when true.","type":{"ki'
            'nd":"NON_NULL","name":null,"ofType":{"name":"Boolean","kind":"SCAL'
            'AR","ofType":null}},"defaultValue":null}]},{"name":"deprecated","d'
            'escription":"Marks an element of a GraphQL schema as no longer sup'
            'ported.","isRepeatable":false,"locations":["FIELD_DEFINITION","ARG'
            'UMENT_DEFINITION","INPUT_FIELD_DEFINITION","ENUM_VALUE","DIRECTIVE'
            '_DEFINITION"],"args":[{"name":"reason","description":"Explains why'
            " this element was deprecated, usually also including a suggestion "
            "for how to access supported similar data. Formatted using the Mark"
            "down syntax, as specified by [CommonMark](https://commonmark.org/)"
            '.","type":{"kind":"SCALAR","name":"String","ofType":null},"default'
            'Value":"\\"No longer supported\\""}]},{"name":"specifiedBy","descr'
            'iption":"Exposes a URL that specifies the behavior of this scalar.'
            '","isRepeatable":false,"locations":["SCALAR"],"args":[{"name":"url'
            '","description":"The URL that specifies the behavior of this scala'
            'r.","type":{"kind":"NON_NULL","name":null,"ofType":{"name":"String'
            '","kind":"SCALAR","ofType":null}},"defaultValue":null}]},{"name":"'
            'oneOf","description":"Indicates exactly one field must be supplied'
            ' and this field must not be `null`.","isRepeatable":false,"locatio'
            'ns":["INPUT_OBJECT"],"args":[]}]}}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
