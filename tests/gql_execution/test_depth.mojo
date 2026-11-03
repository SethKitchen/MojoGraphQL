# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `MAX_EXECUTION_DEPTH`. There is no upstream suite: graphql-js
has no such limit."""

from std.testing import TestSuite, assert_false, assert_true
from _helpers import json_value
from gql_execution.collect_fields import MAX_COLLECT_DEPTH
from gql_execution.execute import (
    MAX_EXECUTION_DEPTH,
    ExecutionArgs,
    ResolveInfo,
    execute_sync,
)
from gql_execution.value import Values
from gql_language.parser import parse
from gql_schema.build import build_schema


def _same(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.copy(source)


def _chain(levels: Int) -> String:
    """A query `levels` objects deep, one fragment a level, so that the
    parsed document stays shallow."""
    var text = String("{ ...F0 }")
    for index in range(levels):
        text += (
            " fragment F"
            + String(index)
            + " on Query { a { ...F"
            + String(index + 1)
            + " } }"
        )
    text += " fragment F" + String(levels) + " on Query { b }"
    return text^


def _run(levels: Int) raises -> String:
    var schema = build_schema("type Query { a: Query b: Boolean }")
    var args = ExecutionArgs()
    args.root_value = json_value(args.values, '{"b":true}')
    args.resolvers.field("Query", "a", _same)
    return execute_sync(schema, parse(_chain(levels)), args).to_json()


def test_a_deep_chain_of_fragments_is_a_field_error() raises:
    # Without the limit, this operation overflows the stack.
    var deep = _run(MAX_EXECUTION_DEPTH * 10)
    assert_true(
        '"message":"The operation is nested deeper than 500 levels."' in deep,
        deep,
    )
    assert_false('"b":true' in deep)


def test_a_chain_under_the_limit_executes() raises:
    var fits = _run(MAX_EXECUTION_DEPTH - 1)
    assert_false('"errors"' in fits, fits)
    assert_true('"b":true' in fits)


def test_a_deep_chain_of_spreads_is_an_error() raises:
    # Fragments that only spread the next one: the collector follows them
    # in one plan. Without its limit, this overflows the stack.
    var text = String("{ ...F0 }")
    for index in range(MAX_COLLECT_DEPTH * 40):
        text += (
            " fragment F"
            + String(index)
            + " on Query { ...F"
            + String(index + 1)
            + " }"
        )
    text += " fragment F" + String(MAX_COLLECT_DEPTH * 40) + " on Query { b }"
    var schema = build_schema("type Query { a: Query b: Boolean }")
    var args = ExecutionArgs()
    var result = execute_sync(schema, parse(text), args).to_json()
    assert_true(
        '"message":"Fragment spreads are nested deeper than 500 levels."'
        in result,
        result,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
