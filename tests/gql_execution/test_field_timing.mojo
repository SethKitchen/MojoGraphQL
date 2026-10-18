# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `ExecutionArgs.field_timing`, the field hook of the Apollo
Server inline trace plugin.

graphql-js 16.14.2 has no such hook. Apollo Server 5.5.1
`utils/schemaInstrumentation.ts` wraps the resolver of each field of the
object types whose names do not start with `__`, so these tests check
that the same fields get a timing, in the order that their resolvers
start, and that a timed execution gives the same result.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _helpers import json_value
from gql_execution.execute import (
    ExecutionArgs,
    ResolveInfo,
    execute,
)
from gql_execution.value import Values
from gql_language.error import PathSegment
from gql_language.parser import parse
from gql_schema.build import build_schema

comptime SDL = """
type Query {
  a: A
  list: [A]
  fails: String
  sum(x: Int!): Int
  t: __Type
}
type A {
  b: String!
  c: [Int]
}
"""
"""The schema of the tests."""

comptime ROOT = '{"a":{"b":"x","c":[1,2]},"list":[{"b":"y"},{"b":"z"}]}'
"""The root value."""


def fails(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Resolve `Query.fails`: always raise."""
    raise Error("It broke")


def sum(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Resolve `Query.sum`: the argument."""
    return values.get(args, "x")


def _args(timed: Bool, root: String = ROOT) raises -> ExecutionArgs:
    """Arguments with the resolvers and the root value."""
    var args = ExecutionArgs()
    args.resolvers.field("Query", "fails", fails)
    args.resolvers.field("Query", "sum", sum)
    args.root_value = json_value(args.values, root)
    args.field_timing = timed
    return args^


def _path(path: List[PathSegment]) -> String:
    """The path as `a.0.b`."""
    var out = String("")
    for ref segment in path:
        if out.byte_length() > 0:
            out += "."
        out += String(segment)
    return out^


def test_records_each_resolved_field() raises:
    var schema = build_schema(SDL)
    var document = parse("{ a { b c } list { b } other: a { b } __typename }")
    var args = _args(True)
    var result = execute(schema, document, args)
    var expected: List[String] = [
        "a A Query",
        "a.b String! A",
        "a.c [Int] A",
        "list [A] Query",
        "list.0.b String! A",
        "list.1.b String! A",
        "other A Query",
        "other.b String! A",
    ]
    assert_equal(len(result.field_timings), len(expected))
    for index in range(len(expected)):
        ref timing = result.field_timings[index]
        assert_equal(
            _path(timing.path)
            + " "
            + schema.type_name(timing.return_type)
            + " "
            + schema.types[timing.parent_type].name,
            expected[index],
        )
        assert_true(timing.end_ns >= timing.start_ns)
        if index > 0:
            assert_true(
                timing.start_ns >= result.field_timings[index - 1].start_ns
            )
    assert_equal(result.field_timings[6].field_name, "a")
    var untimed = _args(False)
    var plain = execute(schema, document, untimed)
    assert_equal(len(plain.field_timings), 0)
    assert_equal(result.to_json(), plain.to_json())


def test_records_a_failed_resolver() raises:
    var schema = build_schema(SDL)
    var args = _args(True)
    var result = execute(schema, parse("{ fails sum(x: 2) }"), args)
    assert_equal(
        result.to_json(),
        (
            '{"errors":[{"message":"It'
            ' broke","locations":[{"line":1,"column":3}],'
            '"path":["fails"]}],"data":{"fails":null,"sum":2}}'
        ),
    )
    assert_equal(len(result.field_timings), 2)
    assert_equal(_path(result.field_timings[0].path), "fails")
    assert_true(
        result.field_timings[0].end_ns >= result.field_timings[0].start_ns
    )
    assert_equal(_path(result.field_timings[1].path), "sum")


def test_argument_errors_come_before_the_resolver() raises:
    var schema = build_schema(SDL)
    var args = _args(True)
    var result = execute(schema, parse("query ($x: Int) { sum(x: $x) }"), args)
    assert_equal(len(result.errors), 1)
    assert_equal(len(result.field_timings), 0)


def test_skips_introspection_types_and_meta_fields() raises:
    var schema = build_schema(SDL)
    var args = _args(True, '{"t":{"name":"T"}}')
    var result = execute(
        schema, parse("{ t { name } __schema { queryType { name } } }"), args
    )
    assert_false(result.to_json().startswith('{"errors"'))
    assert_equal(len(result.field_timings), 1)
    assert_equal(_path(result.field_timings[0].path), "t")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
