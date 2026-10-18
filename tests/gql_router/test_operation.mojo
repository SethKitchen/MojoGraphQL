# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the operation and variable definitions of the planner.

Upstream `bin/router/src/query_planner/ast/operation.rs` has no tests of
its own for these helpers. The expected texts are upstream `Display`.
"""

from gql_language.ast import Role
from gql_language.parser import parse
from gql_router.ast import NONE
from gql_router.federation_spec import OperationKind, TypeNode
from gql_router.operation import (
    OperationDefinition,
    VariableDefinition,
    value_from_ast,
    values_equal,
)
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _value(mut store: Store, text: String) raises -> Int:
    """Read the value of the first argument of `{ f(a: <text>) }`."""
    var document = parse("{ f(a: " + text + ") }")
    var operation = document.child(document.root, Role.DEFINITION)
    var set = document.child(operation, Role.SELECTION_SET)
    var field = document.child(set, Role.SELECTION)
    var argument = document.child(field, Role.ARGUMENT)
    return value_from_ast(store, document, document.child(argument, Role.VALUE))


def test_values_equal() raises:
    var store = Store()
    var one = _value(store, "[1, {a: 2}]")
    var same = _value(store, "[1, {a: 2}]")
    var float = _value(store, "[1.0, {a: 2}]")
    assert_true(values_equal(store, one, same))
    assert_false(values_equal(store, one, float))
    assert_true(values_equal(store, NONE, NONE))
    assert_false(values_equal(store, one, NONE))


def test_variable_definitions_merge_only_when_equal() raises:
    var store = Store()
    var id = store.sym("id")
    var named = TypeNode(store.sym("ID"), "%!")
    var a = VariableDefinition(id, named.copy(), _value(store, "1"))
    assert_true(
        a.can_merge(
            store, VariableDefinition(id, named.copy(), _value(store, "1"))
        )
    )
    assert_false(
        a.can_merge(
            store, VariableDefinition(store.sym("x"), named.copy(), NONE)
        )
    )
    assert_false(
        a.can_merge(
            store, VariableDefinition(id, TypeNode(store.sym("ID"), "%"), NONE)
        )
    )
    assert_false(a.can_merge(store, VariableDefinition(id, named.copy(), NONE)))


def test_operation_text_with_variables() raises:
    var store = Store()
    var operation = OperationDefinition(OperationKind.QUERY, store.new_set())
    operation.name = store.sym("Q")
    operation.has_variables = True
    operation.variables.append(
        VariableDefinition(
            store.sym("a"), TypeNode(store.sym("Int"), "%"), _value(store, "1")
        )
    )
    operation.variables.append(
        VariableDefinition(
            store.sym("b"), TypeNode(store.sym("Int"), "[%!]"), NONE
        )
    )
    assert_equal(operation.text(store), "query Q ($a:Int=1, $b:[Int!])")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
