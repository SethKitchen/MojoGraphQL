# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the planner store: values, argument maps, directives and type
sets.

Upstream keeps these values in `graphql-parser` and `BTreeMap` types, so it
has no tests of its own for them. The expected texts are upstream `Value`
`Display`.
"""

from gql_language.ast import NO_NODE, Role
from gql_language.parser import parse
from gql_router.ast import NONE, ItemKind, ValueKind
from gql_router.operation import value_from_ast
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _args(mut store: Store, query: String) raises -> List[List[Int]]:
    """Read the argument names and values of the first field of a query."""
    var document = parse(query)
    var operation = document.child(document.root, Role.DEFINITION)
    var set = document.child(operation, Role.SELECTION_SET)
    var field = document.child(set, Role.SELECTION)
    var names = List[Int]()
    var values = List[Int]()
    var argument = document.child(field, Role.ARGUMENT)
    while argument != NO_NODE:
        names.append(store.sym(document.name(argument)))
        values.append(
            value_from_ast(
                store, document, document.child(argument, Role.VALUE)
            )
        )
        argument = document.next_with_role(argument)
    return [names^, values^]


def test_argument_map_text_and_variables() raises:
    var store = Store()
    var read = _args(
        store,
        (
            '{ f(e: {}, d: {y: 1, x: 2, x: 3}, c: [1, 2.5, "s", true, false,'
            " null, E, $v], b: $v, a: $w, a: $w) }"
        ),
    )
    var id = store.intern_args(read[0], read[1])
    assert_equal(
        store.args[id].text,
        (
            'a: $w, b: $v, c: [1, 2.5, "s", true, false, null, E, $v], d: {x:'
            " 3, y: 1}, e: {}"
        ),
    )
    assert_equal(len(store.args[id].variables), 2)
    assert_equal(store.name(store.args[id].variables[0]), "v")
    assert_equal(store.name(store.args[id].variables[1]), "w")
    # The same map again is the same id.
    var again = _args(
        store,
        (
            '{ f(a: $w, b: $v, c: [1, 2.5, "s", true, false, null, E, $v], d:'
            " {x: 3, y: 1}, e: {}) }"
        ),
    )
    assert_equal(store.intern_args(again[0], again[1]), id)
    assert_equal(store.intern_args(List[Int](), List[Int]()), NONE)
    assert_equal(store.value_text(read[1][0]), "{}")


def test_variables_already_in_order() raises:
    var store = Store()
    var read = _args(store, "{ f(a: $v, b: $w) }")
    var id = store.intern_args(read[0], read[1])
    assert_equal(store.name(store.args[id].variables[0]), "v")
    assert_equal(store.name(store.args[id].variables[1]), "w")


def test_arg_value() raises:
    var store = Store()
    var read = _args(store, "{ f(a: 1, b: 2) }")
    var id = store.intern_args(read[0], read[1])
    assert_equal(store.value_text(store.arg_value(id, store.sym("b"))), "2")
    assert_equal(store.arg_value(id, store.sym("c")), NONE)
    assert_equal(store.arg_value(NONE, store.sym("a")), NONE)


def test_int_out_of_range_raises() raises:
    var store = Store()
    with assert_raises(contains="out of i64 range"):
        _ = _args(store, "{ f(a: 99999999999999999999) }")


def test_directives() raises:
    var store = Store()
    var read = _args(store, '{ f(if: $x, other: "s") }')
    var variable = store.intern_args([read[0][0]], [read[1][0]])
    var text = store.intern_args([store.sym("if")], [read[1][1]])
    var skip = store.sym("skip")
    var by_variable = store.directive(skip, variable)
    assert_equal(store.name(store.directives[by_variable].if_variable), "x")
    assert_equal(store.directive(skip, variable), by_variable)
    var by_text = store.directive(skip, text)
    assert_equal(store.directives[by_text].if_variable, NONE)
    assert_equal(store.directives[by_text].if_boolean, NONE)
    var bare = store.directive(store.sym("foo"), NONE)
    assert_equal(store.directives[bare].if_boolean, NONE)
    assert_equal(store.directive_list(List[Int]()), NONE)
    var list = store.directive_list([by_variable, bare])
    assert_equal(store.directive_list([by_variable, bare]), list)
    assert_equal(len(store.directive_items(list)), 2)
    assert_equal(len(store.directive_items(NONE)), 0)


def test_type_sets() raises:
    var store = Store()
    var b = store.sym("B")
    var a = store.sym("A")
    var empty = store.type_set(List[Int]())
    assert_equal(len(store.type_sets[empty]), 0)
    var both = store.type_set([b, a, b])
    assert_equal(store.type_sets[both], [a, b])
    assert_equal(store.type_set([a, b]), both)


def test_mark_and_rollback() raises:
    var store = Store()
    var mark = store.mark()
    _ = store.add_item(ItemKind.FIELD, store.sym("a"))
    assert_equal(len(store.items), mark + 1)
    store.rollback(mark)
    assert_equal(len(store.items), mark)


def test_floats_are_tagged_in_keys() raises:
    var store = Store()
    var read = _args(store, "{ f(a: 1.0) }")
    var out = String()
    store.write_value(out, read[1][0], True)
    assert_equal(out, "1f")
    assert_true(store.values[read[1][0]].kind == ValueKind.FLOAT)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
