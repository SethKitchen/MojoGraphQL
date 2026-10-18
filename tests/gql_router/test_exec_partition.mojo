# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the split of an operation into its downstream and
introspection parts.

Upstream Hive Router `1a29df9`
`bin/router/src/executor/introspection/partition.rs` has no tests. These
tests check the rules of upstream `partition_selection_set`. The expected
texts are upstream `OperationDefinition` `Display`.
"""

from _fixtures import simple_requires
from gql_router.ast import ItemKind
from gql_router.exec_partition import partition_operation
from gql_router.federation_spec import OperationKind
from gql_router.operation import OperationDefinition
from gql_router.planner import Planner
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _split(query: String) raises -> List[String]:
    """Return the downstream text, the introspection text, and "yes" or
    "no" for `has_introspection`."""
    var planner = Planner(simple_requires.sdl())
    var operation = planner.normalize(query)
    var before = operation.text(planner.store)
    var parts = partition_operation(planner.store, operation)
    var out = List[String]()
    out.append(parts.downstream_operation.text(planner.store))
    out.append(parts.introspection_operation.text(planner.store))
    out.append("yes" if parts.has_introspection else "no")
    # The input operation does not change.
    assert_equal(operation.text(planner.store), before)
    return out^


def _check(
    query: String, downstream: String, introspection: String, has: String
) raises:
    """Split a query and compare the two parts."""
    var out = _split(query)
    assert_equal(out[0], downstream)
    assert_equal(out[1], introspection)
    assert_equal(out[2], has)


def test_root_schema_field_goes_to_introspection() raises:
    _check(
        "{ __schema { queryType { name } } products { upc } }",
        "{products{upc}}",
        "{__schema{queryType{name}}}",
        "yes",
    )


def test_root_type_field_goes_to_introspection() raises:
    _check(
        '{ __type(name: "Product") { name } }',
        "",
        '{__type(name: "Product"){name}}',
        "yes",
    )


def test_typename_stays_downstream() raises:
    _check(
        "{ __typename products { __typename upc } }",
        "{__typename products{__typename upc}}",
        "",
        "no",
    )


def test_no_introspection() raises:
    _check("{ products { upc } }", "{products{upc}}", "", "no")


def test_flattened_fragments_split() raises:
    _check(
        "{ ... on Query { __schema { types { name } } products { upc } } }",
        "{products{upc}}",
        "{__schema{types{name}}}",
        "yes",
    )


def test_nested_introspection_field_splits_its_parent() raises:
    _check(
        '{ products { __type(name: "X") { name } upc } }',
        "{products{upc}}",
        '{products{__type(name: "X"){name}}}',
        "yes",
    )
    # A field with only introspection selections is not sent downstream.
    _check(
        '{ products { __type(name: "X") { name } } }',
        "",
        '{products{__type(name: "X"){name}}}',
        "yes",
    )


def test_introspection_keeps_the_variables_it_uses() raises:
    _check(
        (
            "query Q($n: String!, $s: Boolean!, $i: Boolean!, $u: Int) {"
            " __type(name: $n) @skip(if: $s) { name } products @include(if:"
            " $i) { upc } }"
        ),
        (
            "query Q ($n:String!, $s:Boolean!, $i:Boolean!,"
            " $u:Int){products @include(if: $i){upc}}"
        ),
        (
            "query Q ($n:String!, $s:Boolean!){__type(name: $n) @skip(if:"
            " $s){name}}"
        ),
        "yes",
    )
    # A variable that two fields use is kept once.
    _check(
        (
            "query Q($u: Int, $n: String!) { a: __type(name: $n) { name } b:"
            " __type(name: $n) { kind } }"
        ),
        "query Q ($u:Int, $n:String!)",
        (
            "query Q ($n:String!){a: __type(name: $n){name} b: __type(name:"
            " $n){kind}}"
        ),
        "yes",
    )
    _check(
        "query Q($n: String!, $u: Int) { products { upc } }",
        "query Q ($n:String!, $u:Int){products{upc}}",
        "query Q ",
        "no",
    )


def _field(mut store: Store, name: StringSlice) -> Int:
    """Add a field with no children."""
    return store.add_item(ItemKind.FIELD, store.sym(name))


def _fragment(mut store: Store, type_name: StringSlice) -> Int:
    """Add an inline fragment with no children."""
    return store.add_item(ItemKind.FRAGMENT, store.sym(type_name))


def test_inline_fragments_and_spreads() raises:
    # Normalization flattens these fragments, so the test builds the
    # selections itself: `{...F ...on Query{__schema{description} a
    # ...on Query{__type{name}}} ...on Query{}}`.
    var store = Store()
    var root = store.new_set()
    store.append(root, store.add_item(ItemKind.SPREAD, store.sym("F")))
    var mixed = _fragment(store, "Query")
    var schema = _field(store, "__schema")
    store.append(schema, _field(store, "description"))
    store.append(mixed, schema)
    store.append(mixed, _field(store, "a"))
    var inner = _fragment(store, "Query")
    var type_field = _field(store, "__type")
    store.append(type_field, _field(store, "name"))
    store.append(inner, type_field)
    store.append(mixed, inner)
    store.append(root, mixed)
    store.append(root, _fragment(store, "Query"))
    var operation = OperationDefinition(OperationKind.QUERY, root)
    var before = operation.text(store)
    var parts = partition_operation(store, operation)
    assert_true(parts.has_introspection)
    assert_equal(
        parts.downstream_operation.text(store), "{...F ...on Query{a}}"
    )
    assert_equal(
        parts.introspection_operation.text(store),
        "{...on Query{__schema{description} ...on Query{__type{name}}}}",
    )
    assert_equal(operation.text(store), before)
    assert_false(parts.introspection_operation.has_variables)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
