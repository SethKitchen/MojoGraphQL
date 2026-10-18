# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the federation directives that the planner reads.

Upstream `bin/router/src/query_planner/federation_spec/` has no tests of its
own for these readers. The error texts are the upstream panic messages.
"""

from gql_language.ast import NO_NODE, Role
from gql_language.parser import parse
from gql_router.ast import NONE
from gql_router.federation_spec import (
    OperationKind,
    PERCENTAGE_SCALE_FACTOR,
    TypeNode,
    parse_join_type,
    parse_override_label,
    type_node_from_text,
)
from gql_router.store import Store
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_operation_kinds() raises:
    assert_true(OperationKind.SUBSCRIPTION.is_valid())
    assert_false(OperationKind(3).is_valid())
    assert_equal(String(OperationKind.MUTATION), "mutation")


def test_type_node_text() raises:
    var store = Store()
    var node = type_node_from_text(store, "[Int!]!")
    assert_equal(node.shape, "[%!]!")
    assert_true(node.is_list())
    assert_equal(node.text(store), "[Int!]!")
    assert_equal(TypeNode(store.sym("ID"), "%").text(store), "ID")


def test_type_node_from_text_errors() raises:
    var store = Store()
    with assert_raises(contains="cannot be empty"):
        _ = type_node_from_text(store, "")
    with assert_raises(contains="Mismatched brackets"):
        _ = type_node_from_text(store, "[Int")
    with assert_raises(contains="Invalid named type format"):
        _ = type_node_from_text(store, "In]t")
    with assert_raises(contains="Invalid named type format"):
        _ = type_node_from_text(store, "In[t")
    with assert_raises(contains="Invalid named type format"):
        _ = type_node_from_text(store, "[In!t]")


def test_override_labels() raises:
    var store = Store()
    var custom = parse_override_label(store, "canary")
    assert_false(custom.is_percent)
    assert_equal(store.name(custom.custom), "canary")
    var open = parse_override_label(store, "percent(5")
    assert_false(open.is_percent)
    var fraction = parse_override_label(store, "percent(11.12)")
    assert_true(fraction.is_percent)
    assert_equal(
        fraction.percent, UInt64(11.12 * Float64(PERCENTAGE_SCALE_FACTOR))
    )
    assert_equal(parse_override_label(store, "percent(100)").custom, NONE)
    with assert_raises(contains="Invalid precision"):
        _ = parse_override_label(store, "percent(1.123456789)")
    with assert_raises(contains="Must be between 0 and 100"):
        _ = parse_override_label(store, "percent(abc)")
    with assert_raises(contains="Must be between 0 and 100"):
        _ = parse_override_label(store, "percent(-1)")
    with assert_raises(contains="Must be between 0 and 100"):
        _ = parse_override_label(store, "percent(150)")


def test_join_type_arguments_of_other_kinds() raises:
    var store = Store()
    var document = parse(
        'type T @join__type(graph: 1, key: E, resolvable: "x")'
        ' @join__type(graph: A, key: "id", resolvable: false,'
        " isInterfaceObject: true) { a: Int }"
    )
    var definition = document.definitions()[0]
    var first = document.child(definition, Role.DIRECTIVE)
    var second = document.next_with_role(first)
    assert_true(second != NO_NODE)
    var odd = parse_join_type(store, document, first)
    assert_equal(store.name(odd.graph_id), "")
    assert_false(Bool(odd.key))
    assert_true(odd.resolvable)
    assert_false(odd.is_interface_object)
    var plain = parse_join_type(store, document, second)
    assert_equal(store.name(plain.graph_id), "A")
    assert_equal(plain.key.value(), "id")
    assert_false(plain.resolvable)
    assert_true(plain.is_interface_object)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
