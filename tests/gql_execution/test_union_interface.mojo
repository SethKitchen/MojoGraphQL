# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for unions and interfaces in `gql_execution.execute`, ported
from graphql-js 16.14.2 `src/execution/__tests__/union-interface-test.ts`.

The upstream data is a graph with cycles (`garfield.mother.progeny =
[garfield]`), so each `Dog`, `Cat` and `Person` is a handle: the tag is
the class and the id names the instance. One field resolver reads the
properties of an instance, and `isTypeOf` and `resolveType` check the
tag, as `instanceof` does. The expected results are those of graphql-js.

Upstream cases that are not ported:

- `handles promises from isTypeOf correctly when a later type matches
  synchronously`: it needs an `isTypeOf` that returns a promise.
- The `schema` check of `gets execution info in resolver`: `ResolveInfo`
  holds no schema. The context and root value checks are ported.
"""

from std.testing import TestSuite, assert_equal, assert_true
from _helpers import json_value, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import UNDEFINED, Values
from gql_schema.build import build_schema

comptime SDL = """
interface Named { name: String }
interface Life { progeny: [Life] }
interface Mammal implements Life { progeny: [Mammal] mother: Mammal father: Mammal }
type Dog implements Mammal & Life & Named {
  name: String
  barks: Boolean
  progeny: [Dog]
  mother: Dog
  father: Dog
}
type Cat implements Mammal & Life & Named {
  name: String
  meows: Boolean
  progeny: [Cat]
  mother: Cat
  father: Cat
}
union Pet = Dog | Cat
type Person implements Named & Mammal & Life {
  name: String
  pets: [Pet]
  friends: [Named]
  progeny: [Person]
  mother: Person
  father: Person
}
schema { query: Person }
"""
comptime DOG = 1
comptime CAT = 2
comptime PERSON = 3
# The instances: Garfield, Garfield's Mom, Odie, Odie's Mom, Liz, John, and
# the John of `gets execution info in resolver`.
comptime NAMES = "Garfield|Garfield's Mom|Odie|Odie's Mom|Liz|John|John"


def _instance(mut values: Values, id: Int) -> Int:
    var tag = CAT if id < 2 else (DOG if id < 4 else PERSON)
    return values.add_handle(tag, id)


def _list(mut values: Values, ids: List[Int]) -> Int:
    var out = values.add_list()
    for id in ids:
        var item = _instance(values, id)
        values.append(out, item)
    return out


def instance_field(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var id = values.id(source)
    var name = info.field_name
    if name == "name":
        return values.add_string(StringSlice(NAMES).split("|")[id])
    if name == "barks" or name == "meows":
        return values.add_bool(id == 2 or id == 3)
    if name == "mother":
        if id == 0 or id == 2:
            return _instance(values, id + 1)
        return UNDEFINED
    if name == "progeny":
        if id == 1 or id == 3:
            return _list(values, [id - 1])
        if id < 4:
            return _list(values, [])
        return UNDEFINED
    if name == "pets":
        if id == 5:
            return _list(values, [0, 2])
        if id == 6:
            return _list(values, [])
        return UNDEFINED
    if name == "friends":
        if id == 5:
            return _list(values, [4, 2])
        if id == 6:
            return _list(values, [4])
        return UNDEFINED
    return UNDEFINED


def is_dog(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    return values.tag(value) == DOG


def is_cat(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    return values.tag(value) == CAT


def is_person(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    return values.tag(value) == PERSON


def pet_type(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    return values.add_string("Dog" if values.tag(value) == DOG else "Cat")


def _args(root: Int) -> ExecutionArgs:
    var args = ExecutionArgs()
    args.resolvers.field_resolver(instance_field)
    args.resolvers.is_type_of("Dog", is_dog)
    args.resolvers.is_type_of("Cat", is_cat)
    args.resolvers.is_type_of("Person", is_person)
    args.resolvers.type_resolver("Pet", pet_type)
    if root >= 0:
        args.root_value = _instance(args.values, root)
    return args^


def check(query: String, variables: String, expected: String) raises:
    var schema = build_schema(SDL)
    var args = _args(5)
    assert_equal(run_query(schema, query, args), expected)


def check_no_root(query: String, variables: String, expected: String) raises:
    var schema = build_schema(SDL)
    var args = _args(-1)
    assert_equal(run_query(schema, query, args), expected)


def record_named(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    values.set(
        info.context_value, "root", values.add_number(Float64(info.root_value))
    )
    return values.add_string("Person")


def test_gets_execution_info_in_resolver() raises:
    var schema = build_schema(
        "interface Named { name: String } type Person implements Named {"
        " name: String friends: [Named] } schema { query: Person }"
    )
    var args = ExecutionArgs()
    args.resolvers.field_resolver(instance_field)
    args.resolvers.type_resolver("Named", record_named)
    args.root_value = _instance(args.values, 6)
    args.context_value = json_value(args.values, '{"authToken": "123abc"}')
    assert_equal(
        run_query(schema, "{ name, friends { name } }", args),
        '{"data":{"name":"John","friends":[{"name":"Liz"}]}}',
    )
    ref values = args.values
    assert_equal(
        Int(values.number(values.get(args.context_value, "root"))),
        args.root_value,
    )
    assert_equal(
        values.string(values.get(args.context_value, "authToken")), "123abc"
    )


def test_can_introspect_on_union_and_intersection_types() raises:
    check_no_root(
        """
      {
        Named: __type(name: "Named") {
          kind
          name
          fields { name }
          interfaces { name }
          possibleTypes { name }
          enumValues { name }
          inputFields { name }
        }
        Mammal: __type(name: "Mammal") {
          kind
          name
          fields { name }
          interfaces { name }
          possibleTypes { name }
          enumValues { name }
          inputFields { name }
        }
        Pet: __type(name: "Pet") {
          kind
          name
          fields { name }
          interfaces { name }
          possibleTypes { name }
          enumValues { name }
          inputFields { name }
        }
      }
    """,
        "",
        (
            '{"data":{"Named":{"kind":"INTERFACE","name":"Named","fields":[{"na'
            'me":"name"}],"interfaces":[],"possibleTypes":[{"name":"Dog"},{"nam'
            'e":"Cat"},{"name":"Person"}],"enumValues":null,"inputFields":null}'
            ',"Mammal":{"kind":"INTERFACE","name":"Mammal","fields":[{"name":"p'
            'rogeny"},{"name":"mother"},{"name":"father"}],"interfaces":[{"name'
            '":"Life"}],"possibleTypes":[{"name":"Dog"},{"name":"Cat"},{"name":'
            '"Person"}],"enumValues":null,"inputFields":null},"Pet":{"kind":"UN'
            'ION","name":"Pet","fields":null,"interfaces":null,"possibleTypes":'
            '[{"name":"Dog"},{"name":"Cat"}],"enumValues":null,"inputFields":nu'
            "ll}}}"
        ),
    )


def test_executes_using_union_types() raises:
    check(
        """
      {
        __typename
        name
        pets {
          __typename
          name
          barks
          meows
        }
      }
    """,
        "",
        (
            '{"data":{"__typename":"Person","name":"John","pets":[{"__typename"'
            ':"Cat","name":"Garfield","meows":false},{"__typename":"Dog","name"'
            ':"Odie","barks":true}]}}'
        ),
    )


def test_executes_union_types_with_inline_fragments() raises:
    check(
        """
      {
        __typename
        name
        pets {
          __typename
          ... on Dog {
            name
            barks
          }
          ... on Cat {
            name
            meows
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__typename":"Person","name":"John","pets":[{"__typename"'
            ':"Cat","name":"Garfield","meows":false},{"__typename":"Dog","name"'
            ':"Odie","barks":true}]}}'
        ),
    )


def test_executes_using_interface_types() raises:
    check(
        """
      {
        __typename
        name
        friends {
          __typename
          name
          barks
          meows
        }
      }
    """,
        "",
        (
            '{"data":{"__typename":"Person","name":"John","friends":[{"__typena'
            'me":"Person","name":"Liz"},{"__typename":"Dog","name":"Odie","bark'
            's":true}]}}'
        ),
    )


def test_executes_interface_types_with_inline_fragments() raises:
    check(
        """
      {
        __typename
        name
        friends {
          __typename
          name
          ... on Dog {
            barks
          }
          ... on Cat {
            meows
          }

          ... on Mammal {
            mother {
              __typename
              ... on Dog {
                name
                barks
              }
              ... on Cat {
                name
                meows
              }
            }
          }
        }
      }
    """,
        "",
        (
            '{"data":{"__typename":"Person","name":"John","friends":[{"__typena'
            'me":"Person","name":"Liz","mother":null},{"__typename":"Dog","name'
            '":"Odie","barks":true,"mother":{"__typename":"Dog","name":"Odie\'s'
            ' Mom","barks":true}}]}}'
        ),
    )


def test_executes_interface_types_with_named_fragments() raises:
    check(
        """
      {
        __typename
        name
        friends {
          __typename
          name
          ...DogBarks
          ...CatMeows
        }
      }

      fragment  DogBarks on Dog {
        barks
      }

      fragment  CatMeows on Cat {
        meows
      }
    """,
        "",
        (
            '{"data":{"__typename":"Person","name":"John","friends":[{"__typena'
            'me":"Person","name":"Liz"},{"__typename":"Dog","name":"Odie","bark'
            's":true}]}}'
        ),
    )


def test_allows_fragment_conditions_to_be_abstract_types() raises:
    check(
        """
      {
        __typename
        name
        pets {
          ...PetFields,
          ...on Mammal {
            mother {
              ...ProgenyFields
            }
          }
        }
        friends { ...FriendFields }
      }

      fragment PetFields on Pet {
        __typename
        ... on Dog {
          name
          barks
        }
        ... on Cat {
          name
          meows
        }
      }

      fragment FriendFields on Named {
        __typename
        name
        ... on Dog {
          barks
        }
        ... on Cat {
          meows
        }
      }

      fragment ProgenyFields on Life {
        progeny {
          __typename
        }
      }
    """,
        "",
        (
            '{"data":{"__typename":"Person","name":"John","pets":[{"__typename"'
            ':"Cat","name":"Garfield","meows":false,"mother":{"progeny":[{"__ty'
            'pename":"Cat"}]}},{"__typename":"Dog","name":"Odie","barks":true,"'
            'mother":{"progeny":[{"__typename":"Dog"}]}}],"friends":[{"__typena'
            'me":"Person","name":"Liz"},{"__typename":"Dog","name":"Odie","bark'
            's":true}]}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
