# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for resolvers in `gql_execution.execute`, ported from graphql-js
16.14.2 `src/execution/__tests__/resolve-test.ts`.

A JavaScript method that the default field resolver calls becomes a field
resolver that reads the same properties, since an arena value has no
methods. Every upstream case is ported that way.
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import UNDEFINED, ValueKind, Values
from gql_language.error import quote_json_string
from gql_schema.build import build_schema
from gql_schema.values import js_number_to_string


def to_json(values: Values, value: Int) -> String:
    """Return `JSON.stringify` of a value; `undefined` is `null`."""
    var kind = values.kind(value)
    if kind == ValueKind.STRING:
        return quote_json_string(String(values.string(value)))
    if kind == ValueKind.NUMBER:
        return js_number_to_string(values.number(value))
    if kind == ValueKind.OBJECT:
        var out = String("{")
        var member = values.first(value)
        while member != UNDEFINED:
            if out != "{":
                out += ","
            out += quote_json_string(String(values.key(member))) + ":"
            out += to_json(values, member)
            member = values.next(member)
        return out + "}"
    return String("null")


def secret(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.copy(values.get(source, "_secret"))


def add(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_number(
        values.number(values.get(source, "_num"))
        + values.number(values.get(args, "addend1"))
        + values.number(values.get(info.context_value, "addend2"))
    )


def source_and_args(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string(
        "[" + to_json(values, source) + "," + to_json(values, args) + "]"
    )


def test_default_function_accesses_properties() raises:
    assert_equal(
        run("type Query { test: String }", "{ test }", '{"test": "testValue"}'),
        '{"data":{"test":"testValue"}}',
    )


def test_default_function_calls_methods() raises:
    var schema = build_schema("type Query { test: String }")
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"_secret": "secretValue"}')
    args.resolvers.field("Query", "test", secret)
    assert_equal(
        run_query(schema, "{ test }", args), '{"data":{"test":"secretValue"}}'
    )


def test_default_function_passes_args_and_context() raises:
    var schema = build_schema("type Query { test(addend1: Int): Int }")
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"_num": 700}')
    args.context_value = json_value(args.values, '{"addend2": 9}')
    args.resolvers.field("Query", "test", add)
    assert_equal(
        run_query(schema, "{ test(addend1: 80) }", args),
        '{"data":{"test":789}}',
    )


def _provided(query: String, root: String) raises -> String:
    var schema = build_schema(
        "type Query { test(aStr: String, aInt: Int): String }"
    )
    var args = ExecutionArgs()
    if root != "":
        args.root_value = json_value(args.values, root)
    args.resolvers.field("Query", "test", source_and_args)
    return run_query(schema, query, args)


def test_uses_provided_resolve_function() raises:
    assert_equal(_provided("{ test }", ""), '{"data":{"test":"[null,{}]"}}')
    assert_equal(
        _provided("{ test }", '"Source!"'),
        '{"data":{"test":"[\\"Source!\\",{}]"}}',
    )
    assert_equal(
        _provided('{ test(aStr: "String!") }', '"Source!"'),
        '{"data":{"test":"[\\"Source!\\",{\\"aStr\\":\\"String!\\"}]"}}',
    )
    assert_equal(
        _provided('{ test(aInt: -123, aStr: "String!") }', '"Source!"'),
        '{"data":{"test":"[\\"Source!\\",{\\"aStr\\":\\"String!\\",\\"aInt\\":-123}]"}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
