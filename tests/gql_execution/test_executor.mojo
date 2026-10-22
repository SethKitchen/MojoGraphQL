# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_execution.execute`, ported from graphql-js 16.14.2
`src/execution/__tests__/executor-test.ts`.

The schemas come from SDL. A JavaScript resolver becomes a Mojo resolver
that returns the same value, and a value that a JavaScript test keeps in a
variable is kept in the context object of the arena.

Upstream cases that are not ported:

- `throws if no document is provided`, `throws if no schema is provided`:
  the Mojo arguments are typed.
- The promise cases of `nulls out error subtrees`, `nulls error subtree
  for promise rejection #1071`, `handles sync errors combined with
  rejections`, `correct field ordering despite execution order` and the
  async half of `fails when an isTypeOf check is not met`: execution is
  synchronous. The synchronous fields of those cases are ported.
- `syncRawError` (a thrown string) and the `extensions` of a returned
  error: a Mojo resolver raises an `Error`, and an error value has only a
  message.
- `fails when serialize of custom scalar does not return a value`: a
  scalar from SDL serializes as the identity.
- The `schema` and `fragments` keys of `provides info about current
  execution state`: `ResolveInfo` holds no schema; the other keys are
  checked.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _helpers import json_value, run, run_query
from gql_execution.execute import (
    ExecutionArgs,
    ResolveInfo,
    execute,
    execute_sync,
)
from gql_execution.value import UNDEFINED, ValueKind, Values, inspect
from gql_language.ast import Role
from gql_language.parser import parse
from gql_schema.build import BuildOptions, build_schema
from gql_schema.values import js_number_to_string


# --- resolvers -------------------------------------------------------------


def pic(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var size = values.number(values.get(args, "size"))
    return values.add_string("Pic of size: " + js_number_to_string(size))


def deep(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var out = json_value(values, '{"a": "Already Been Done", "b": "Boring"}')
    var c = values.add_list()
    values.append(c, values.add_string("Contrived"))
    values.append(c, values.add_undefined())
    values.append(c, values.add_string("Confusing"))
    values.add_member(out, "c", c)
    return out


def deeper(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var out = values.add_list()
    values.append(out, values.copy(info.root_value))
    values.append(out, values.add_null())
    values.append(out, values.copy(info.root_value))
    return out


def promise(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.copy(info.root_value)


def apple(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("Apple")


def banana(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("Banana")


def cherry(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("Cherry")


def empty_object(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_object()


def record_info(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var context = info.context_value
    values.set(context, "fieldName", values.add_string(info.field_name))
    var path = String("")
    for segment in info.path:
        path += String(segment) + "/"
    values.set(context, "path", values.add_string(path))
    values.set(
        context, "parentType", values.add_number(Float64(info.parent_type))
    )
    values.set(
        context,
        "returnType",
        values.add_number(Float64(info.return_type.named)),
    )
    values.set(
        context,
        "returnTypeWrapped",
        values.add_bool(info.return_type.is_wrapped()),
    )
    values.set(context, "operation", values.add_number(Float64(info.operation)))
    values.set(
        context, "nodes", values.add_number(Float64(len(info.field_nodes)))
    )
    values.set(
        context, "firstNode", values.add_number(Float64(info.field_nodes[0]))
    )
    values.set(context, "sameRoot", values.add_bool(source == info.root_value))
    values.set(
        context,
        "variables",
        values.add_string(inspect(values, info.variable_values)),
    )
    return UNDEFINED


def some_object(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    return values.add_string("SomeObject")


def show_args(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string(inspect(values, args))


def record_args(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    values.set(
        info.context_value, "args", values.add_string(inspect(values, args))
    )
    return UNDEFINED


def sync_value(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("sync")


def sync_error(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    raise Error("Error getting syncError")


def sync_return_error(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_error("Error getting syncReturnError")


def sync_return_error_list(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var out = values.add_list()
    values.append(out, values.add_string("sync0"))
    values.append(out, values.add_error("Error getting syncReturnErrorList1"))
    values.append(out, values.add_string("sync2"))
    values.append(out, values.add_error("Error getting syncReturnErrorList3"))
    return out


def async_value(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_promise(values.add_string("async"))


def async_reject(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_rejected_promise("Error getting asyncReject")


def async_return_error(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_promise(
        values.add_error("Error getting asyncReturnError")
    )


def async_return_error_with_extensions(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_promise(
        values.add_error("Error getting asyncReturnErrorWithExtensions")
    )


def is_special_async(
    mut values: Values, value: Int, info: ResolveInfo
) raises -> Int:
    var found = values.get(value, "value")
    var ok = False
    if values.kind(found) == ValueKind.STRING:
        if values.string(found) == "foo":
            ok = True
    return values.add_promise(values.add_bool(ok))


def catch_me(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    raise Error("Catch me if you can")


def is_special(
    mut values: Values, value: Int, info: ResolveInfo
) raises -> Bool:
    var found = values.get(value, "value")
    return (
        values.kind(found) == ValueKind.STRING and values.string(found) == "foo"
    )


def field_name(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string(info.field_name)


def foo_object(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    values.set(
        info.context_value,
        "abstract",
        values.add_number(Float64(abstract_type)),
    )
    return values.add_string("FooObject")


# --- tests -------------------------------------------------------------------


def test_throws_on_invalid_variables() raises:
    var schema = build_schema(
        "type Type { fieldA(argA: Int): String }  schema { query: Type }"
    )
    var args = ExecutionArgs()
    args.variable_values = args.values.add_string('{ "a": 1 }')
    var raised = False
    try:
        _ = run_query(schema, "query ($a: Int) { fieldA(argA: $a) }", args)
    except e:
        raised = True
        assert_equal(
            String(e),
            (
                "Variables must be provided as an Object where each property is"
                " a variable value. Perhaps look to see if an unparsed JSON"
                " string was provided."
            ),
        )
    assert_true(raised)


def test_executes_arbitrary_code() raises:
    var schema = build_schema(
        """
        schema { query: DataType }
        type DataType {
          a: String
          b: String
          c: String
          d: String
          e: String
          f: String
          pic(size: Int): String
          deep: DeepDataType
          promise: DataType
        }
        type DeepDataType {
          a: String
          b: String
          c: [String]
          deeper: [DataType]
        }
        """
    )
    var args = ExecutionArgs()
    args.root_value = json_value(
        args.values,
        (
            '{"a": "Apple", "b": "Banana", "c": "Cookie", "d": "Donut", "e":'
            ' "Egg", "f": "Fish"}'
        ),
    )
    args.variable_values = json_value(args.values, '{"size": 100}')
    args.resolvers.field("DataType", "pic", pic)
    args.resolvers.field("DataType", "deep", deep)
    args.resolvers.field("DataType", "promise", promise)
    args.resolvers.field("DeepDataType", "deeper", deeper)
    var query = """
      query ($size: Int) {
        a,
        b,
        x: c
        ...c
        f
        ...on DataType {
          pic(size: $size)
          promise {
            a
          }
        }
        deep {
          a
          b
          c
          deeper {
            a
            b
          }
        }
      }

      fragment c on DataType {
        d
        e
      }
    """
    assert_equal(
        run_query(schema, query, args),
        (
            '{"data":{"a":"Apple","b":"Banana","x":"Cookie","d":"Donut","e":"Egg",'
            '"f":"Fish","pic":"Pic of size:'
            ' 100","promise":{"a":"Apple"},"deep":'
            '{"a":"Already Been Done","b":"Boring","c":["Contrived",null,'
            '"Confusing"],"deeper":[{"a":"Apple","b":"Banana"},null,{"a":"Apple",'
            '"b":"Banana"}]}}}'
        ),
    )


def test_merges_parallel_fragments() raises:
    var schema = build_schema(
        "type Type { a: String b: String c: String deep: Type }"
        " schema { query: Type }"
    )
    var args = ExecutionArgs()
    args.resolvers.field("Type", "a", apple)
    args.resolvers.field("Type", "b", banana)
    args.resolvers.field("Type", "c", cherry)
    args.resolvers.field("Type", "deep", empty_object)
    var query = """
      { a, ...FragOne, ...FragTwo }

      fragment FragOne on Type {
        b
        deep { b, deeper: deep { b } }
      }

      fragment FragTwo on Type {
        c
        deep { c, deeper: deep { c } }
      }
    """
    assert_equal(
        run_query(schema, query, args),
        (
            '{"data":{"a":"Apple","b":"Banana","deep":{"b":"Banana","deeper":'
            '{"b":"Banana","c":"Cherry"},"c":"Cherry"},"c":"Cherry"}}'
        ),
    )


def test_provides_info_about_current_execution_state() raises:
    var schema = build_schema(
        "type Test { test: String } schema { query: Test }"
    )
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"root": "val"}')
    args.variable_values = json_value(args.values, '{"var": "abc"}')
    args.context_value = args.values.add_object()
    args.resolvers.field("Test", "test", record_info)
    var document = parse("query ($var: String) { result: test }")
    _ = execute(schema, document, args)
    ref values = args.values
    var context = args.context_value
    assert_equal(values.string(values.get(context, "fieldName")), "test")
    assert_equal(values.string(values.get(context, "path")), "result/")
    assert_equal(
        Int(values.number(values.get(context, "parentType"))),
        schema.type_named("Test"),
    )
    assert_equal(
        Int(values.number(values.get(context, "returnType"))),
        schema.type_named("String"),
    )
    assert_false(values.bool_value(values.get(context, "returnTypeWrapped")))
    var operation = document.definitions()[0]
    assert_equal(
        Int(values.number(values.get(context, "operation"))), operation
    )
    assert_equal(Int(values.number(values.get(context, "nodes"))), 1)
    assert_equal(
        Int(values.number(values.get(context, "firstNode"))),
        document.children(
            document.child(operation, Role.SELECTION_SET), Role.SELECTION
        )[0],
    )
    assert_true(values.bool_value(values.get(context, "sameRoot")))
    assert_equal(
        values.string(values.get(context, "variables")), '{ var: "abc" }'
    )


def test_populates_path_correctly_with_complex_types() raises:
    var schema = build_schema(
        """
        type SomeObject { test: String }
        union SomeUnion = SomeObject
        type SomeQuery { test: [SomeUnion!]! }
        schema { query: SomeQuery }
        """
    )
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"test": [{}]}')
    args.context_value = args.values.add_object()
    args.resolvers.field("SomeObject", "test", record_info)
    args.resolvers.type_resolver("SomeUnion", some_object)
    _ = run_query(
        schema,
        "query { l1: test { ... on SomeObject { l2: test } } }",
        args,
    )
    assert_equal(
        args.values.string(args.values.get(args.context_value, "path")),
        "l1/0/l2/",
    )


def test_threads_root_value_context_correctly() raises:
    var schema = build_schema("type Type { a: String } schema { query: Type }")
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"contextThing": "thing"}')
    args.context_value = args.values.add_object()
    args.resolvers.field("Type", "a", record_info)
    _ = run_query(schema, "query Example { a }", args)
    assert_true(
        args.values.bool_value(args.values.get(args.context_value, "sameRoot"))
    )


def test_correctly_threads_arguments() raises:
    var schema = build_schema(
        "type Type { b(numArg: Int, stringArg: String): String }"
        " schema { query: Type }"
    )
    var args = ExecutionArgs()
    args.context_value = args.values.add_object()
    args.resolvers.field("Type", "b", record_args)
    _ = run_query(
        schema, 'query Example { b(numArg: 123, stringArg: "foo") }', args
    )
    assert_equal(
        args.values.string(args.values.get(args.context_value, "args")),
        '{ numArg: 123, stringArg: "foo" }',
    )


def test_nulls_out_error_subtrees() raises:
    var schema = build_schema(
        """
        type Type {
          sync: String
          syncError: String
          syncReturnError: String
          syncReturnErrorList: [String]
          async: String
          asyncReject: String
          asyncReturnError: String
          asyncReturnErrorWithExtensions: String
        }
        schema { query: Type }
        """
    )
    var args = ExecutionArgs()
    args.resolvers.field("Type", "sync", sync_value)
    args.resolvers.field("Type", "syncError", sync_error)
    args.resolvers.field("Type", "syncReturnError", sync_return_error)
    args.resolvers.field("Type", "syncReturnErrorList", sync_return_error_list)
    args.resolvers.field("Type", "async", async_value)
    args.resolvers.field("Type", "asyncReject", async_reject)
    args.resolvers.field("Type", "asyncReturnError", async_return_error)
    args.resolvers.field(
        "Type",
        "asyncReturnErrorWithExtensions",
        async_return_error_with_extensions,
    )
    var query = """
      {
        sync
        syncError
        syncReturnError
        syncReturnErrorList
        async
        asyncReject
        asyncReturnError
        asyncReturnErrorWithExtensions
      }
    """
    assert_equal(
        run_query(schema, query, args),
        (
            '{"errors":[{"message":"Error getting'
            ' syncError","locations":[{"line":'
            '4,"column":9}],"path":["syncError"]},{"message":"Error getting'
            ' syncReturnError","locations":[{"line":5,"column":9}],"path":'
            '["syncReturnError"]},{"message":"Error getting'
            ' syncReturnErrorList1",'
            '"locations":[{"line":6,"column":9}],"path":["syncReturnErrorList",1]},'
            '{"message":"Error getting'
            ' syncReturnErrorList3","locations":[{"line":'
            '6,"column":9}],"path":["syncReturnErrorList",3]},{"message":"Error'
            ' getting asyncReject","locations":[{"line":8,"column":9}],"path":'
            '["asyncReject"]},{"message":"Error getting'
            ' asyncReturnError","locations":[{"line":9,"column":9}],"path":'
            '["asyncReturnError"]},{"message":"Error getting'
            ' asyncReturnErrorWithExtensions","locations":[{"line":10,"column":9'
            '}],"path":["asyncReturnErrorWithExtensions"]}],"data":{"sync":'
            '"sync","syncError":null,"syncReturnError":null,"syncReturnErrorList":'
            '["sync0",null,"sync2",null],"async":"async","asyncReject":null,'
            '"asyncReturnError":null,"asyncReturnErrorWithExtensions":null}}'
        ),
    )


def test_full_response_path_is_included_for_non_nullable_fields() raises:
    var schema = build_schema(
        """
        type A {
          nullableA: A
          nonNullA: A!
          throws: String!
        }
        type query { nullableA: A }
        schema { query: query }
        """
    )
    var args = ExecutionArgs()
    args.resolvers.field("query", "nullableA", empty_object)
    args.resolvers.field("A", "nullableA", empty_object)
    args.resolvers.field("A", "nonNullA", empty_object)
    args.resolvers.field("A", "throws", catch_me)
    var query = """
      query {
        nullableA {
          aliasedA: nullableA {
            nonNullA {
              anotherA: nonNullA {
                throws
              }
            }
          }
        }
      }
    """
    assert_equal(
        run_query(schema, query, args),
        (
            '{"errors":[{"message":"Catch me if you'
            ' can","locations":[{"line":7,'
            '"column":17}],"path":["nullableA","aliasedA","nonNullA","anotherA",'
            '"throws"]}],"data":{"nullableA":{"aliasedA":null}}}'
        ),
    )


comptime TYPE_A = "type Type { a: String } schema { query: Type }"


def test_uses_the_inline_operation_if_no_operation_name_is_provided() raises:
    assert_equal(run(TYPE_A, "{ a }", '{"a": "b"}'), '{"data":{"a":"b"}}')


def test_uses_the_only_operation_if_no_operation_name_is_provided() raises:
    assert_equal(
        run(TYPE_A, "query Example { a }", '{"a": "b"}'), '{"data":{"a":"b"}}'
    )


def _named(sdl: String, query: String, name: String) raises -> String:
    var schema = build_schema(sdl)
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"a": "b", "c": "d"}')
    args.operation_name = name
    return run_query(schema, query, args)


def test_uses_the_named_operation_if_operation_name_is_provided() raises:
    assert_equal(
        _named(
            TYPE_A,
            "query Example { first: a } query OtherExample { second: a }",
            "OtherExample",
        ),
        '{"data":{"second":"b"}}',
    )


def test_provides_error_if_no_operation_is_provided() raises:
    assert_equal(
        run(TYPE_A, "fragment Example on Type { a }", '{"a": "b"}'),
        '{"errors":[{"message":"Must provide an operation."}]}',
    )


def test_errors_if_no_op_name_is_provided_with_multiple_operations() raises:
    assert_equal(
        run(TYPE_A, "query Example { a } query OtherExample { a }"),
        (
            '{"errors":[{"message":"Must provide operation name if query'
            ' contains multiple operations."}]}'
        ),
    )


def test_errors_if_unknown_operation_name_is_provided() raises:
    assert_equal(
        _named(
            TYPE_A,
            "query Example { a } query OtherExample { a }",
            "UnknownExample",
        ),
        (
            '{"errors":[{"message":"Unknown operation named'
            ' \\"UnknownExample\\"."}]}'
        ),
    )


def test_errors_if_empty_string_is_provided_as_operation_name() raises:
    assert_equal(
        _named(TYPE_A, "{ a }", ""),
        '{"errors":[{"message":"Unknown operation named \\"\\"."}]}',
    )


comptime QMS = (
    "type Q { a: String } type M { c: String } type S { a: String }"
    " schema { query: Q mutation: M subscription: S }"
)


def test_uses_the_query_schema_for_queries() raises:
    assert_equal(
        _named(QMS, "query Q { a } mutation M { c } subscription S { a }", "Q"),
        '{"data":{"a":"b"}}',
    )


def test_uses_the_mutation_schema_for_mutations() raises:
    assert_equal(
        _named(QMS, "query Q { a } mutation M { c }", "M"),
        '{"data":{"c":"d"}}',
    )


def test_uses_the_subscription_schema_for_subscriptions() raises:
    assert_equal(
        _named(QMS, "query Q { a } subscription S { a }", "S"),
        '{"data":{"a":"b"}}',
    )


def test_resolves_to_an_error_if_schema_does_not_support_operation() raises:
    var options = BuildOptions()
    options.assume_valid = True
    var schema = build_schema("scalar Unused", options)
    var query = """
      query Q { __typename }
      mutation M { __typename }
      subscription S { __typename }
    """
    var expected: List[String] = [
        (
            '{"errors":[{"message":"Schema is not configured to execute query'
            ' operation.","locations":[{"line":2,"column":7}]}],"data":null}'
        ),
        (
            '{"errors":[{"message":"Schema is not configured to execute'
            " mutation"
            ' operation.","locations":[{"line":3,"column":7}]}],"data":null}'
        ),
        (
            '{"errors":[{"message":"Schema is not configured to execute'
            ' subscription operation.","locations":[{"line":4,"column":7}]}],'
            '"data":null}'
        ),
    ]
    var names: List[String] = ["Q", "M", "S"]
    var index = 0
    while index < 3:
        var args = ExecutionArgs()
        args.assume_valid_schema = True
        args.operation_name = names[index]
        assert_equal(run_query(schema, query, args), expected[index])
        index += 1


def test_correct_field_ordering() raises:
    assert_equal(
        run(
            (
                "type Type { a: String b: String c: String d: String e: String"
                " } schema { query: Type }"
            ),
            "{ a, b, c, d, e }",
            '{"a": "a", "b": "b", "c": "c", "d": "d", "e": "e"}',
        ),
        '{"data":{"a":"a","b":"b","c":"c","d":"d","e":"e"}}',
    )


def test_avoids_recursion() raises:
    assert_equal(
        run(
            TYPE_A,
            "{ a ...Frag ...Frag } fragment Frag on Type { a, ...Frag }",
            '{"a": "b"}',
        ),
        '{"data":{"a":"b"}}',
    )


def test_ignores_missing_sub_selections_on_fields() raises:
    assert_equal(
        run(
            "type SomeType { b: String } type Query { a: SomeType }",
            "{ a }",
            '{"a": {"b": "c"}}',
        ),
        '{"data":{"a":{}}}',
    )


def test_does_not_include_illegal_fields_in_output() raises:
    assert_equal(
        run(
            "type Q { a: String } schema { query: Q }",
            "{ thisIsIllegalDoNotIncludeMe }",
        ),
        '{"data":{}}',
    )


def test_does_not_include_arguments_that_were_not_set() raises:
    var schema = build_schema(
        "type Type { field(a: Boolean, b: Boolean, c: Boolean, d: Int, e:"
        " Int): String } schema { query: Type }"
    )
    var args = ExecutionArgs()
    args.resolvers.field("Type", "field", show_args)
    assert_equal(
        run_query(schema, "{ field(a: true, c: false, e: 0) }", args),
        '{"data":{"field":"{ a: true, c: false, e: 0 }"}}',
    )


def test_fails_when_an_is_type_of_check_is_not_met() raises:
    var schema = build_schema(
        "type SpecialType { value: String } type Query { specials:"
        " [SpecialType] }"
    )
    var args = ExecutionArgs()
    args.root_value = json_value(
        args.values, '{"specials": [{"value": "foo"}, {"value": "bar"}]}'
    )
    args.resolvers.is_type_of("SpecialType", is_special)
    assert_equal(
        run_query(schema, "{ specials { value } }", args),
        (
            '{"errors":[{"message":"Expected value of type'
            ' \\"SpecialType\\" but'
            ' got: { value: \\"bar\\" }.","locations":[{"line":1,"column":3}],'
            '"path":["specials",1]}],"data":{"specials":[{"value":"foo"},null]}}'
        ),
    )
    var args2 = ExecutionArgs()
    args2.root_value = json_value(
        args2.values, '{"specials": [{"value": "foo"}, {"value": "bar"}]}'
    )
    args2.resolvers.async_is_type_of("SpecialType", is_special_async)
    assert_equal(
        run_query(schema, "{ specials { value } }", args2),
        (
            '{"errors":[{"message":"Expected value of type'
            ' \\"SpecialType\\" but'
            ' got: { value: \\"bar\\" }.","locations":[{"line":1,"column":3}],'
            '"path":["specials",1]}],"data":{"specials":[{"value":"foo"},null]}}'
        ),
    )


def test_executes_ignoring_invalid_non_executable_definitions() raises:
    assert_equal(
        run(
            "type Query { foo: String }",
            "{ foo } type Query { bar: String }",
        ),
        '{"data":{"foo":null}}',
    )


def test_uses_a_custom_field_resolver() raises:
    var schema = build_schema("type Query { foo: String }")
    var args = ExecutionArgs()
    args.resolvers.field_resolver(field_name)
    assert_equal(run_query(schema, "{ foo }", args), '{"data":{"foo":"foo"}}')


def test_uses_a_custom_type_resolver() raises:
    var schema = build_schema(
        """
        interface FooInterface { bar: String }
        type FooObject implements FooInterface { bar: String }
        type Query { foo: FooInterface }
        """
    )
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"foo": {"bar": "bar"}}')
    args.context_value = args.values.add_object()
    args.resolvers.default_type_resolver(foo_object)
    assert_equal(
        run_query(schema, "{ foo { bar } }", args),
        '{"data":{"foo":{"bar":"bar"}}}',
    )
    var abstract = Int(
        args.values.number(args.values.get(args.context_value, "abstract"))
    )
    var possible = schema.possible_types(abstract)
    assert_equal(len(possible), 1)
    assert_equal(possible[0], schema.type_named("FooObject"))


def test_uses_a_different_number_of_max_coercion_errors() raises:
    var schema = build_schema(
        """
        type Query { dummy: String }
        input User { email: String! }
        type Mutation { updateUser(data: User): String }
        """
    )
    var args = ExecutionArgs()
    args.max_coercion_errors = 1
    args.variable_values = json_value(
        args.values,
        (
            '{"data": {"email": "", "wrongArg": "wrong", "wrongArg2": "wrong",'
            ' "wrongArg3": "wrong"}}'
        ),
    )
    assert_equal(
        run_query(
            schema,
            (
                "\n      mutation ($data: User) {\n        updateUser(data:"
                " $data)\n      }\n    "
            ),
            args,
        ),
        (
            '{"errors":[{"message":"Variable \\"$data\\" got invalid value {'
            ' email: \\"\\", wrongArg: \\"wrong\\", wrongArg2: \\"wrong\\",'
            ' wrongArg3: \\"wrong\\" }; Field \\"wrongArg\\" is not defined by'
            ' type \\"User\\"."'
            ',"locations":[{"line":2,"column":17}]},{"message":"Too many errors'
            ' processing variables, error limit reached. Execution aborted."}]}'
        ),
    )


# --- not upstream ------------------------------------------------------------


def test_execute_with_no_arguments() raises:
    var schema = build_schema("type Query { a: String }")
    assert_equal(
        execute(schema, parse("{ a __typename }")).to_json(),
        '{"data":{"a":null,"__typename":"Query"}}',
    )


def test_execute_sync_is_execute() raises:
    var schema = build_schema("type Query { a: String }")
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"a": "x"}')
    var result = execute_sync(schema, parse("{ a }"), args)
    assert_true(result.has_data())
    assert_equal(result^.take_data().root, 0)


def test_execute_raises_for_an_invalid_schema() raises:
    var options = BuildOptions()
    options.assume_valid = True
    var schema = build_schema("type Query", options)
    var document = parse("{ __typename }")
    var raised = False
    try:
        _ = execute(schema, document)
    except e:
        raised = True
        assert_equal(String(e), "Type Query must define one or more fields.")
    assert_true(raised)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
