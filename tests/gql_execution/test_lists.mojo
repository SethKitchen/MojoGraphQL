# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for list completion in `gql_execution.execute`, ported from
graphql-js 16.14.2 `src/execution/__tests__/lists-test.ts`.

A list value is JSON, where the string `"!bad"` stands for `new
Error('bad')`. The expected results are those of graphql-js 16.14.2 with
the same values.

Upstream cases that are not ported:

- `Accepts a Set`, `an Generator function` and `function arguments` as a
  list value: an arena has arrays only. The string case is ported.
- The promise forms of each nullability case: execution is synchronous.
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run, run_query
from gql_execution.execute import ExecutionArgs
from gql_execution.value import UNDEFINED, ValueKind, Values
from gql_schema.build import build_schema


def _value(mut values: Values, json: Int) raises -> Int:
    """Turn `"!bad"` strings of a JSON value into error values."""
    var kind = values.kind(json)
    if kind == ValueKind.STRING and values.string(json) == "!bad":
        return values.add_error("bad")
    if kind != ValueKind.LIST:
        return json
    var out = values.add_list()
    var item = values.first(json)
    while item != UNDEFINED:
        var next = values.next(item)
        var converted = _value(values, values.copy(item))
        values.append(out, converted)
        item = next
    return out


def check(spec: String, type: String, expected: String) raises:
    var schema = build_schema("type Query { listField: " + type + " }")
    var args = ExecutionArgs()
    var root = args.values.add_object()
    var list = _value(args.values, json_value(args.values, spec))
    args.values.add_member(root, "listField", list)
    args.root_value = root
    assert_equal(run_query(schema, "{ listField }", args), expected)


def test_does_not_accept_a_string_literal_as_a_list_value() raises:
    assert_equal(
        run(
            "type Query { listField: [String] }",
            "{ listField }",
            '{"listField": "Singular"}',
        ),
        (
            '{"errors":[{"message":"Expected Iterable, but did not find one for'
            " field"
            ' \\"Query.listField\\".","locations":[{"line":1,"column":3}],'
            '"path":["listField"]}],"data":{"listField":null}}'
        ),
    )


def test_contains_values_list() raises:
    check(
        "[1,2]",
        "[Int]",
        '{"data":{"listField":[1,2]}}',
    )


def test_contains_values_list_non_null() raises:
    check(
        "[1,2]",
        "[Int]!",
        '{"data":{"listField":[1,2]}}',
    )


def test_contains_values_list_of_non_null() raises:
    check(
        "[1,2]",
        "[Int!]",
        '{"data":{"listField":[1,2]}}',
    )


def test_contains_values_list_of_non_null_non_null() raises:
    check(
        "[1,2]",
        "[Int!]!",
        '{"data":{"listField":[1,2]}}',
    )


def test_contains_null_list() raises:
    check(
        "[1,null,2]",
        "[Int]",
        '{"data":{"listField":[1,null,2]}}',
    )


def test_contains_null_list_non_null() raises:
    check(
        "[1,null,2]",
        "[Int]!",
        '{"data":{"listField":[1,null,2]}}',
    )


def test_contains_null_list_of_non_null() raises:
    check(
        "[1,null,2]",
        "[Int!]",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field Q'
            'uery.listField.","locations":[{"line":1,"column":3}],"path":["list'
            'Field",1]}],"data":{"listField":null}}'
        ),
    )


def test_contains_null_list_of_non_null_non_null() raises:
    check(
        "[1,null,2]",
        "[Int!]!",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field Q'
            'uery.listField.","locations":[{"line":1,"column":3}],"path":["list'
            'Field",1]}],"data":null}'
        ),
    )


def test_returns_null_list() raises:
    check(
        "null",
        "[Int]",
        '{"data":{"listField":null}}',
    )


def test_returns_null_list_non_null() raises:
    check(
        "null",
        "[Int]!",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field Q'
            'uery.listField.","locations":[{"line":1,"column":3}],"path":["list'
            'Field"]}],"data":null}'
        ),
    )


def test_returns_null_list_of_non_null() raises:
    check(
        "null",
        "[Int!]",
        '{"data":{"listField":null}}',
    )


def test_returns_null_list_of_non_null_non_null() raises:
    check(
        "null",
        "[Int!]!",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field Q'
            'uery.listField.","locations":[{"line":1,"column":3}],"path":["list'
            'Field"]}],"data":null}'
        ),
    )


def test_contains_error_list() raises:
    check(
        '[1,"!bad",2]',
        "[Int]",
        (
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":3}],"p'
            'ath":["listField",1]}],"data":{"listField":[1,null,2]}}'
        ),
    )


def test_contains_error_list_non_null() raises:
    check(
        '[1,"!bad",2]',
        "[Int]!",
        (
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":3}],"p'
            'ath":["listField",1]}],"data":{"listField":[1,null,2]}}'
        ),
    )


def test_contains_error_list_of_non_null() raises:
    check(
        '[1,"!bad",2]',
        "[Int!]",
        (
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":3}],"p'
            'ath":["listField",1]}],"data":{"listField":null}}'
        ),
    )


def test_contains_error_list_of_non_null_non_null() raises:
    check(
        '[1,"!bad",2]',
        "[Int!]!",
        (
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":3}],"p'
            'ath":["listField",1]}],"data":null}'
        ),
    )


def test_results_in_error_list() raises:
    check(
        '"!bad"',
        "[Int]",
        (
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":3}],"p'
            'ath":["listField"]}],"data":{"listField":null}}'
        ),
    )


def test_results_in_error_list_non_null() raises:
    check(
        '"!bad"',
        "[Int]!",
        (
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":3}],"p'
            'ath":["listField"]}],"data":null}'
        ),
    )


def test_results_in_error_list_of_non_null() raises:
    check(
        '"!bad"',
        "[Int!]",
        (
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":3}],"p'
            'ath":["listField"]}],"data":{"listField":null}}'
        ),
    )


def test_results_in_error_list_of_non_null_non_null() raises:
    check(
        '"!bad"',
        "[Int!]!",
        (
            '{"errors":[{"message":"bad","locations":[{"line":1,"column":3}],"p'
            'ath":["listField"]}],"data":null}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
