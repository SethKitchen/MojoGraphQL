# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_execution.execute` that are not upstream.

Each expected result is that of graphql-js 16.14.2 in Node.js for the same
schema, document and values. Where graphql-js needs a JavaScript object to
set up a case, such as a deprecated directive or a `resolveType` that
returns `null`, the Mojo test sets the same thing on its schema or its
resolvers.
"""

from std.testing import TestSuite, assert_equal, assert_true
from _helpers import json_value, run, run_query
from gql_execution.execute import (
    ExecutionArgs,
    ResolveInfo,
    default_field_resolver,
    execute,
)
from gql_execution.value import UNDEFINED, Values
from gql_language.parser import parse
from gql_schema.build import BuildOptions, build_schema


def nothing(
    mut values: Values, value: Int, info: ResolveInfo, type: Int
) raises -> Int:
    return values.add_null()


def no_idea(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    raise Error("No idea")


def with_undefined(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var out = values.add_object()
    values.add_member(out, "a", values.add_number(1))
    values.add_member(out, "b", values.add_undefined())
    values.add_member(out, "c", values.add_handle(1, 2))
    var list = values.add_list()
    values.append(list, values.add_undefined())
    values.append(list, values.add_error("x"))
    values.add_member(out, "d", list)
    return out


def test_the_default_field_resolver_can_be_set() raises:
    var schema = build_schema("type Query { a: String }")
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"a": "b"}')
    args.resolvers.field_resolver(default_field_resolver)
    assert_equal(run_query(schema, "{ a }", args), '{"data":{"a":"b"}}')


def test_resolvers_of_unknown_elements_are_not_used() raises:
    var schema = build_schema(
        "interface I { a: String } type Query { a: String }"
    )
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"a": "b"}')
    args.resolvers.field("Missing", "a", default_field_resolver)
    args.resolvers.field("Query", "missing", default_field_resolver)
    args.resolvers.type_resolver("Missing", nothing)
    args.resolvers.is_type_of("Missing", no_idea)
    assert_equal(run_query(schema, "{ a }", args), '{"data":{"a":"b"}}')


comptime NON_NULL_A = "type Query { a: String! b: String }"


def test_locations_count_lines_and_utf16_units() raises:
    assert_equal(
        run(NON_NULL_A, "# café 😀\r\n{\r  b\r\n  a\r\n}"),
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field'
            ' Query.a.","locations":[{"line":4,"column":3}],"path":["a"]}],'
            '"data":null}'
        ),
    )
    assert_equal(
        run(NON_NULL_A, '{ b(x: "é😀") a }'),
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field'
            ' Query.a.","locations":[{"line":1,"column":15}],"path":["a"]}],'
            '"data":null}'
        ),
    )


def test_locations_of_field_nodes_out_of_document_order() raises:
    assert_equal(
        run(NON_NULL_A, "{ ...F b a }\nfragment F on Query { a }"),
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field'
            ' Query.a.","locations":[{"line":2,"column":23},{"line":1,"column":10}],'
            '"path":["a"]}],"data":null}'
        ),
    )


def test_meta_fields_of_a_type_that_is_not_the_query_type() raises:
    assert_equal(
        run(
            "type Other { a: String } type Query { other: Other }",
            (
                '{ other { a __schema { description } __type(name: "Other") {'
                " name } } }"
            ),
            '{"other": {"a": "x"}}',
        ),
        '{"data":{"other":{"a":"x"}}}',
    )


comptime NO_RUNTIME_TYPE = (
    '{"errors":[{"message":"Abstract type \\"I\\" must resolve to an Object'
    ' type at runtime for field \\"Query.i\\". Either the \\"I\\" type should'
    ' provide a \\"resolveType\\" function or each possible type should'
    ' provide an \\"isTypeOf\\" function.","locations":[{"line":1,"column":3}],'
    '"path":["i"]}],"data":{"i":null}}'
)


def test_an_interface_with_no_implementations() raises:
    assert_equal(
        run(
            "interface I { a: String } type Query { i: I }",
            "{ i { a } }",
            '{"i": {}}',
        ),
        NO_RUNTIME_TYPE,
    )


def test_a_type_resolver_that_returns_null() raises:
    var schema = build_schema(
        "interface I { a: String } type T implements I { a: String } type Query"
        " { i: I }"
    )
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"i": {}}')
    args.resolvers.type_resolver("I", nothing)
    assert_equal(run_query(schema, "{ i { a } }", args), NO_RUNTIME_TYPE)


def test_an_is_type_of_that_raises_on_an_object_type() raises:
    var schema = build_schema("type T { a: String } type Query { t: T }")
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"t": {}}')
    args.resolvers.is_type_of("T", no_idea)
    assert_equal(
        run_query(schema, "{ t { a } }", args),
        (
            '{"errors":[{"message":"No'
            ' idea","locations":[{"line":1,"column":3}],'
            '"path":["t"]}],"data":{"t":null}}'
        ),
    )


def test_type_of_an_unknown_name_is_null() raises:
    assert_equal(
        run("type Query { a: String }", '{ __type(name: "Unknown") { name } }'),
        '{"data":{"__type":null}}',
    )


def test_an_error_in_an_introspection_list_item_has_its_path() raises:
    assert_equal(
        run(
            "type Query { a: String }",
            (
                "query ($v: Boolean) { __schema { types { name @include(if: $v)"
                " } } }"
            ),
        ),
        (
            '{"errors":[{"message":"Argument \\"if\\" of required type'
            ' \\"Boolean!\\" was provided the variable \\"$v\\" which was not'
            ' provided a runtime value.","locations":[{"line":1,"column":60}],'
            '"path":["__schema","types",0]}],"data":null}'
        ),
    )


def test_deprecated_directives() raises:
    var schema = build_schema(
        "directive @old on QUERY type Query { a: String b: String }"
    )
    var old = schema.directive_named("old")
    schema.directives[old].is_deprecated = True
    schema.directives[old].deprecation_reason = "Gone"
    var args = ExecutionArgs()
    assert_equal(
        run_query(
            schema,
            (
                "{ __schema { directives { name } all:"
                " directives(includeDeprecated: true) { name isDeprecated"
                " deprecationReason } } }"
            ),
            args,
        ),
        (
            '{"data":{"__schema":{"directives":[{"name":"include"},{"name":"skip"},'
            '{"name":"deprecated"},{"name":"specifiedBy"},{"name":"oneOf"}],"all":'
            '[{"name":"old","isDeprecated":true,"deprecationReason":"Gone"},'
            '{"name":"include","isDeprecated":false,"deprecationReason":null},'
            '{"name":"skip","isDeprecated":false,"deprecationReason":null},'
            '{"name":"deprecated","isDeprecated":false,"deprecationReason":null},'
            '{"name":"specifiedBy","isDeprecated":false,"deprecationReason":null},'
            '{"name":"oneOf","isDeprecated":false,"deprecationReason":null}]}}}'
        ),
    )


def test_a_custom_scalar_result_as_json_stringify_writes_it() raises:
    var schema = build_schema("scalar Custom type Query { c: Custom }")
    var args = ExecutionArgs()
    args.resolvers.field("Query", "c", with_undefined)
    assert_equal(
        run_query(schema, "{ c }", args),
        '{"data":{"c":{"a":1,"c":{},"d":[null,{}]}}}',
    )


def test_execute_raises_the_invariant_of_a_variable_default() raises:
    var options = BuildOptions()
    options.assume_valid = True
    options.assume_valid_sdl = True
    var schema = build_schema(
        "input I { a: Query } type Query { f(i: I): Int }", options
    )
    var document = parse("query ($v: I = {a: {}}) { f(i: $v) }")
    var args = ExecutionArgs()
    args.assume_valid_schema = True
    args.root_value = args.values.add_string("kept")
    var raised = False
    try:
        _ = execute(schema, document, args)
    except e:
        raised = True
        assert_equal(String(e), "Unexpected input type: Query")
    assert_true(raised)
    assert_equal(args.values.string(args.root_value), "kept")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
