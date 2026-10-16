# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_execution.values` that are not upstream: argument values
of an invalid schema, and the functions called with no variable values.

graphql-js reaches the `Unexpected input type` invariant of
`valueFromAST` for an argument whose type is an output type; a schema
built with `assumeValid` can have one. The result of
`test_an_argument_of_an_output_type` is that of graphql-js 16.14.2. For
`test_a_default_value_of_an_output_type`, graphql-js `buildSchema` raises
the error, because it coerces each default value when it builds the
schema; `gql_schema` keeps the literal, so execution gives the error as a
field error.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _helpers import run_query
from gql_execution.coerce import ScalarKind
from gql_execution.execute import ExecutionArgs
from gql_execution.value import UNDEFINED, Values, inspect
from gql_execution.values import (
    ArgumentOwner,
    get_argument_values,
    get_directive_values,
)
from gql_language.ast import Role
from gql_language.parser import parse
from gql_schema.build import BuildOptions, build_schema


def test_kinds_are_valid() raises:
    assert_true(ScalarKind.CUSTOM.is_valid())
    assert_false(ScalarKind(6).is_valid())
    assert_false(ScalarKind(-1).is_valid())
    assert_true(ArgumentOwner.DIRECTIVE.is_valid())
    assert_false(ArgumentOwner(2).is_valid())


def _invalid(query: String) raises -> String:
    var options = BuildOptions()
    options.assume_valid = True
    options.assume_valid_sdl = True
    var schema = build_schema(
        "type Query { f(a: Query): Int g(a: Query = {}): Int }", options
    )
    var args = ExecutionArgs()
    args.assume_valid_schema = True
    return run_query(schema, query, args)


def test_an_argument_of_an_output_type() raises:
    assert_equal(
        _invalid("{ f(a: {}) }"),
        (
            '{"errors":[{"message":"Unexpected input type: Query","locations":'
            '[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
    )


def test_a_default_value_of_an_output_type() raises:
    assert_equal(
        _invalid("{ g }"),
        (
            '{"errors":[{"message":"Unexpected input type: Query","locations":'
            '[{"line":1,"column":3}],"path":["g"]}],"data":{"g":null}}'
        ),
    )


def test_arguments_with_no_variable_values() raises:
    var schema = build_schema("type Query { f(a: Int = 3, b: Int): Int }")
    var document = parse("{ f(b: $v) }")
    var operation = document.definitions()[0]
    var selection_set = document.child(operation, Role.SELECTION_SET)
    var field = document.child(selection_set, Role.SELECTION)
    var values = Values()
    var args = get_argument_values(
        schema,
        ArgumentOwner.FIELD,
        schema.field_named(schema.type_named("Query"), "f"),
        document,
        field,
        values,
        UNDEFINED,
    )
    assert_equal(inspect(values, args), "{ a: 3 }")
    var skip = get_directive_values(
        schema,
        schema.directive_named("skip"),
        document,
        field,
        values,
        UNDEFINED,
    )
    assert_equal(skip, UNDEFINED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
