# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for abstract types in `gql_execution.execute`, ported from
graphql-js 16.14.2 `src/execution/__tests__/abstract-test.ts`.

A `Dog` instance is an object with `name` and `woofs`, and a `Cat` one
with `name` and `meows`, so `inspect` shows them as graphql-js does. The
`isTypeOf` of `Dog` checks for `woofs`, as `instanceof Dog` does. The
upstream `types: [...]` order is the order of the type definitions.

Upstream cases that are not ported:

- The async half of each case (`contextValue: { async: true }`): execution
  is synchronous.
- The last check of `resolveType on Interface yields useful error`: a
  resolver cannot return a `GraphQLObjectType`.
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import UNDEFINED, Values
from gql_schema.build import build_schema


def pets(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return json_value(
        values,
        (
            '[{"name": "Odie", "woofs": true}, {"name": "Garfield", "meows":'
            " false}]"
        ),
    )


def empty(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_object()


def is_dog(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    return values.member(value, "woofs") != UNDEFINED


def is_cat(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    return values.member(value, "meows") != UNDEFINED


def throws(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    raise Error("We are testing this error")


def never(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    return False


def resolve_throws(
    mut values: Values, value: Int, info: ResolveInfo, type: Int
) raises -> Int:
    raise Error("We are testing this error")


def resolve_list(
    mut values: Values, value: Int, info: ResolveInfo, type: Int
) raises -> Int:
    return values.add_list()


comptime INTERFACE_SDL = """
    interface Pet { name: String }
    type Dog implements Pet { name: String woofs: Boolean }
    type Cat implements Pet { name: String meows: Boolean }
    type Query { pets: [Pet] pet: Pet }
"""
comptime UNION_SDL = """
    type Dog { name: String woofs: Boolean }
    type Cat { name: String meows: Boolean }
    union Pet = Dog | Cat
    type Query { pets: [Pet] }
"""
comptime PETS_QUERY = """
      {
        pets {
          name
          ... on Dog {
            woofs
          }
          ... on Cat {
            meows
          }
        }
      }
    """
comptime PETS_DATA = (
    '{"data":{"pets":[{"name":"Odie","woofs":true},{"name":"Garfield",'
    '"meows":false}]}}'
)
comptime PETS_ERRORS = (
    '{"errors":[{"message":"We are testing this error","locations":[{"line":'
    '3,"column":9}],"path":["pets",0]},{"message":"We are testing this'
    ' error","locations":[{"line":3,"column":9}],"path":["pets",1]}],"data":'
    '{"pets":[null,null]}}'
)


def test_is_type_of_used_to_resolve_runtime_type_for_interface() raises:
    var schema = build_schema(INTERFACE_SDL)
    var args = ExecutionArgs()
    args.resolvers.field("Query", "pets", pets)
    args.resolvers.is_type_of("Dog", is_dog)
    args.resolvers.is_type_of("Cat", is_cat)
    assert_equal(run_query(schema, PETS_QUERY, args), PETS_DATA)


def test_is_type_of_can_throw() raises:
    var schema = build_schema(INTERFACE_SDL)
    var args = ExecutionArgs()
    args.resolvers.field("Query", "pets", pets)
    args.resolvers.is_type_of("Dog", throws)
    assert_equal(run_query(schema, PETS_QUERY, args), PETS_ERRORS)


def test_is_type_of_can_return_false() raises:
    var schema = build_schema(INTERFACE_SDL)
    var args = ExecutionArgs()
    args.resolvers.field("Query", "pet", empty)
    args.resolvers.is_type_of("Dog", never)
    assert_equal(
        run_query(
            schema,
            (
                "\n      {\n        pet {\n          name\n        }\n     "
                " }\n    "
            ),
            args,
        ),
        (
            '{"errors":[{"message":"Abstract type \\"Pet\\" must resolve to an'
            ' Object type at runtime for field \\"Query.pet\\". Either the'
            ' \\"Pet\\" type should provide a \\"resolveType\\" function or'
            " each"
            ' possible type should provide an \\"isTypeOf\\" function.",'
            '"locations":[{"line":3,"column":9}],"path":["pet"]}],"data":{"pet":'
            "null}}"
        ),
    )


def test_is_type_of_used_to_resolve_runtime_type_for_union() raises:
    var schema = build_schema(UNION_SDL)
    var args = ExecutionArgs()
    args.resolvers.field("Query", "pets", pets)
    args.resolvers.is_type_of("Dog", is_dog)
    args.resolvers.is_type_of("Cat", is_cat)
    var query = """{
      pets {
        ... on Dog {
          name
          woofs
        }
        ... on Cat {
          name
          meows
        }
      }
    }"""
    assert_equal(run_query(schema, query, args), PETS_DATA)


def test_resolve_type_can_throw() raises:
    var schema = build_schema(INTERFACE_SDL)
    var args = ExecutionArgs()
    args.resolvers.field("Query", "pets", pets)
    args.resolvers.type_resolver("Pet", resolve_throws)
    assert_equal(run_query(schema, PETS_QUERY, args), PETS_ERRORS)


comptime TYPENAME_ROOT = (
    '{"pets": [{"__typename": "Dog", "name": "Odie", "woofs": true},'
    ' {"__typename": "Cat", "name": "Garfield", "meows": false}]}'
)


def test_resolve_union_type_using_typename_on_source_object() raises:
    assert_equal(run(UNION_SDL, PETS_QUERY, TYPENAME_ROOT), PETS_DATA)


def test_resolve_interface_type_using_typename_on_source_object() raises:
    assert_equal(run(INTERFACE_SDL, PETS_QUERY, TYPENAME_ROOT), PETS_DATA)


comptime ERROR_SDL = """
      type Query {
        pet: Pet
      }

      interface Pet {
        name: String
      }

      type Cat implements Pet {
        name: String
      }

      type Dog implements Pet {
        name: String
      }
"""
comptime PET_QUERY = (
    "\n      {\n        pet {\n          name\n        }\n      }\n    "
)


def _pet_error(type_name: String, use_list: Bool = False) raises -> String:
    var schema = build_schema(ERROR_SDL)
    var args = ExecutionArgs()
    var root = args.values.add_object()
    var pet = args.values.add_object()
    var typename = args.values.add_undefined()
    if type_name != "":
        typename = args.values.add_string(type_name)
    args.values.add_member(pet, "__typename", typename)
    args.values.add_member(root, "pet", pet)
    args.root_value = root
    if use_list:
        args.resolvers.type_resolver("Pet", resolve_list)
    return run_query(schema, PET_QUERY, args)


def _expected(message: String) -> String:
    return (
        '{"errors":[{"message":"'
        + message
        + '","locations":[{"line":3,"column":9}],"path":["pet"]}],"data":{"pet":null}}'
    )


def test_resolve_type_on_interface_yields_useful_error() raises:
    assert_equal(
        _pet_error(""),
        _expected(
            'Abstract type \\"Pet\\" must resolve to an Object type at runtime'
            ' for field \\"Query.pet\\". Either the \\"Pet\\" type should'
            ' provide a \\"resolveType\\" function or each possible type should'
            ' provide an \\"isTypeOf\\" function.'
        ),
    )
    assert_equal(
        _pet_error("Human"),
        _expected(
            'Abstract type \\"Pet\\" was resolved to a type \\"Human\\" that'
            " does not exist inside the schema."
        ),
    )
    assert_equal(
        _pet_error("String"),
        _expected(
            'Abstract type \\"Pet\\" was resolved to a non-object type'
            ' \\"String\\".'
        ),
    )
    assert_equal(
        _pet_error("__Schema"),
        _expected(
            'Runtime Object type \\"__Schema\\" is not a possible type for'
            ' \\"Pet\\".'
        ),
    )
    assert_equal(
        _pet_error("", True),
        _expected(
            'Abstract type \\"Pet\\" must resolve to an Object type at runtime'
            ' for field \\"Query.pet\\" with value { __typename: undefined },'
            ' received \\"[]\\".'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
