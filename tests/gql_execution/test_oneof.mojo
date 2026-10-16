# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `@oneOf` input objects in execution, ported from graphql-js
16.14.2 `src/execution/__tests__/oneof-test.ts`.

Every upstream execution is ported, with its query and variables; the
root `test` method becomes a field resolver that returns its `input`
argument.
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import Values
from gql_schema.build import build_schema

comptime SDL = """
  type Query {
    test(input: TestInputObject!): TestObject
  }

  input TestInputObject @oneOf {
    a: String
    b: Int
  }

  type TestObject {
    a: String
    b: Int
  }
"""


def input(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.copy(values.get(args, "input"))


def check(query: String, variables: String, expected: String) raises:
    var schema = build_schema(SDL)
    var args = ExecutionArgs()
    args.resolvers.field("Query", "test", input)
    if variables != "":
        args.variable_values = json_value(args.values, variables)
    assert_equal(run_query(schema, query, args), expected)


def test_oneof_input_objects_accepts_a_good_default_value() raises:
    check(
        """
        query ($input: TestInputObject! = {a: "abc"}) {
          test(input: $input) {
            a
            b
          }
        }
      """,
        "",
        '{"data":{"test":{"a":"abc","b":null}}}',
    )


def test_oneof_input_objects_rejects_a_bad_default_value() raises:
    check(
        """
        query ($input: TestInputObject! = {a: "abc", b: 123}) {
          test(input: $input) {
            a
            b
          }
        }
      """,
        "",
        (
            '{"errors":[{"message":"Argument \\"input\\" of non-null type \\"Te'
            'stInputObject!\\" must not be null.","locations":[{"line":3,"colum'
            'n":23}],"path":["test"]}],"data":{"test":null}}'
        ),
    )


def test_oneof_input_objects_accepts_a_good_variable() raises:
    check(
        """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
      """,
        '{"input":{"a":"abc"}}',
        '{"data":{"test":{"a":"abc","b":null}}}',
    )


def test_oneof_input_objects_accepts_a_good_variable_with_an_undefined_key() raises:
    check(
        """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
      """,
        '{"input":{"a":"abc"}}',
        '{"data":{"test":{"a":"abc","b":null}}}',
    )


def test_oneof_input_objects_rejects_a_variable_with_multiple_non_null_keys() raises:
    check(
        """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
      """,
        '{"input":{"a":"abc","b":123}}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value { a'
            ': \\"abc\\", b: 123 }; Exactly one key must be specified for OneOf'
            ' type \\"TestInputObject\\".","locations":[{"line":2,"column":16}]'
            "}]}"
        ),
    )


def test_oneof_input_objects_rejects_a_variable_with_multiple_nullable_keys() raises:
    check(
        """
        query ($input: TestInputObject!) {
          test(input: $input) {
            a
            b
          }
        }
      """,
        '{"input":{"a":"abc","b":null}}',
        (
            '{"errors":[{"message":"Variable \\"$input\\" got invalid value { a'
            ': \\"abc\\", b: null }; Exactly one key must be specified for OneO'
            'f type \\"TestInputObject\\".","locations":[{"line":2,"column":16}'
            "]}]}"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
