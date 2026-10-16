# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for synchronous execution, ported from graphql-js 16.14.2
`src/execution/__tests__/sync-test.ts`.

Upstream cases that are not ported:

- `returns a Promise if any field is asynchronous` and both `throws if
  encountering async execution`: there are no promises.
- The `graphqlSync` cases: `graphql.ts` parses, validates and executes,
  and validation is the `gql_validation` package, which `gql_execution`
  does not depend on.
"""

from std.testing import TestSuite, assert_equal
from _helpers import run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo, execute_sync
from gql_execution.value import Values
from gql_language.parser import parse
from gql_schema.build import build_schema

comptime SDL = """
type Query { syncField: String }
type Mutation { syncMutationField: String }
"""


def root(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.copy(source)


def _run(query: String) raises -> String:
    var schema = build_schema(SDL)
    var args = ExecutionArgs()
    args.root_value = args.values.add_string("rootValue")
    args.resolvers.field("Query", "syncField", root)
    args.resolvers.field("Mutation", "syncMutationField", root)
    return execute_sync(schema, parse(query), args).to_json()


def test_does_not_return_a_promise_for_initial_errors() raises:
    assert_equal(
        _run("fragment Example on Query { syncField }"),
        '{"errors":[{"message":"Must provide an operation."}]}',
    )


def test_does_not_return_a_promise_if_fields_are_all_synchronous() raises:
    assert_equal(
        _run("query Example { syncField }"),
        '{"data":{"syncField":"rootValue"}}',
    )


def test_does_not_return_a_promise_if_mutation_fields_are_all_synchronous() raises:
    assert_equal(
        _run("mutation Example { syncMutationField }"),
        '{"data":{"syncMutationField":"rootValue"}}',
    )


def test_execute_sync_does_not_return_a_promise_for_sync_execution() raises:
    assert_equal(
        _run("query Example { syncField }"),
        '{"data":{"syncField":"rootValue"}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
