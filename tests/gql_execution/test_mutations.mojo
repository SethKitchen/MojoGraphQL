# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for mutations, ported from graphql-js 16.14.2
`src/execution/__tests__/mutations-test.ts`.

The `Root` instance is the object `{ numberHolder: { theNumber: 6 } }`, and
its methods become field resolvers that change the number in the arena.
The `promise` mutations resolve at once, as execution is synchronous;
the results are the upstream ones.
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import Values
from gql_schema.build import build_schema

comptime SDL = """
type NumberHolder { theNumber: Int }
type Query { numberHolder: NumberHolder }
type Mutation {
  immediatelyChangeTheNumber(newNumber: Int): NumberHolder
  promiseToChangeTheNumber(newNumber: Int): NumberHolder
  failToChangeTheNumber(newNumber: Int): NumberHolder
  promiseAndFailToChangeTheNumber(newNumber: Int): NumberHolder
}
"""


def change(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var holder = values.get(source, "numberHolder")
    var number = values.copy(values.get(args, "newNumber"))
    values.set(holder, "theNumber", number)
    return holder


def fail(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    raise Error("Cannot change the number")


def _run(query: String) raises -> String:
    var schema = build_schema(SDL)
    var args = ExecutionArgs()
    args.root_value = json_value(
        args.values, '{"numberHolder": {"theNumber": 6}}'
    )
    args.resolvers.field("Mutation", "immediatelyChangeTheNumber", change)
    args.resolvers.field("Mutation", "promiseToChangeTheNumber", change)
    args.resolvers.field("Mutation", "failToChangeTheNumber", fail)
    args.resolvers.field("Mutation", "promiseAndFailToChangeTheNumber", fail)
    return run_query(schema, query, args)


def test_evaluates_mutations_serially() raises:
    var query = """
      mutation M {
        first: immediatelyChangeTheNumber(newNumber: 1) {
          theNumber
        },
        second: promiseToChangeTheNumber(newNumber: 2) {
          theNumber
        },
        third: immediatelyChangeTheNumber(newNumber: 3) {
          theNumber
        }
        fourth: promiseToChangeTheNumber(newNumber: 4) {
          theNumber
        },
        fifth: immediatelyChangeTheNumber(newNumber: 5) {
          theNumber
        }
      }
    """
    assert_equal(
        _run(query),
        (
            '{"data":{"first":{"theNumber":1},"second":{"theNumber":2},"third":'
            '{"theNumber":3},"fourth":{"theNumber":4},"fifth":{"theNumber":5}}}'
        ),
    )


def test_does_not_include_illegal_mutation_fields_in_output() raises:
    assert_equal(
        _run("mutation { thisIsIllegalDoNotIncludeMe }"), '{"data":{}}'
    )


def test_evaluates_mutations_correctly_in_the_presence_of_a_failed_mutation() raises:
    var query = """
      mutation M {
        first: immediatelyChangeTheNumber(newNumber: 1) {
          theNumber
        },
        second: promiseToChangeTheNumber(newNumber: 2) {
          theNumber
        },
        third: failToChangeTheNumber(newNumber: 3) {
          theNumber
        }
        fourth: promiseToChangeTheNumber(newNumber: 4) {
          theNumber
        },
        fifth: immediatelyChangeTheNumber(newNumber: 5) {
          theNumber
        }
        sixth: promiseAndFailToChangeTheNumber(newNumber: 6) {
          theNumber
        }
      }
    """
    assert_equal(
        _run(query),
        (
            '{"errors":[{"message":"Cannot change the'
            ' number","locations":[{"line":'
            '9,"column":9}],"path":["third"]},{"message":"Cannot change the'
            ' number","locations":[{"line":18,"column":9}],"path":["sixth"]}],'
            '"data":{"first":{"theNumber":1},"second":{"theNumber":2},"third":null,'
            '"fourth":{"theNumber":4},"fifth":{"theNumber":5},"sixth":null}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
