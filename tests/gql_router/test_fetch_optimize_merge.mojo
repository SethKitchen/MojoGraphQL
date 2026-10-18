# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the merge passes of the fetch graph optimizer.

Hive Router `1a29df9` `bin/router/src/query_planner/planner/fetch/
optimize/` (`merge_passthrough_child.rs`, `merge_children_with_parents.rs`,
`merge_siblings.rs`, `merge_leafs.rs`, `deduplicate_and_prune_fetch_steps.rs`
and `turn_mutations_into_sequence.rs`) has no tests of its own; its query
plan tests cover it. Each test here checks one rule on a fetch graph built
by hand.
"""

from _fetch_steps import entity_step, noop_root, path, root_step, selections
from gql_router.ast import NONE
from gql_router.federation_spec import OperationKind
from gql_router.fetch_optimize_merge import (
    can_merge_leafs,
    can_merge_passthrough_child,
    deduplicate_and_prune_fetch_steps,
    merge_children_with_parents,
    merge_siblings,
    perform_passthrough_child_merge,
    turn_mutations_into_sequence,
)
from gql_router.fetch_step import FetchGraph
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_passthrough_child_needs_this_one_parent() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    var parent = graph.add_step(
        root_step(store, "s", "{ a { __typename id } }")
    )
    var other = graph.add_step(root_step(store, "s", "{ b }"))
    var child = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a"]),
            selections(store, ["Book"], ["{ __typename id }"]),
            selections(store, ["Book"], ["{ __typename id }"]),
        )
    )
    _ = graph.connect(root, parent)
    _ = graph.connect(root, other)
    _ = graph.connect(other, child)
    assert_false(can_merge_passthrough_child(store, graph, child, child))
    assert_false(can_merge_passthrough_child(store, graph, parent, child))
    # A merge also gives the child's other parents to the parent.
    _ = graph.connect(parent, child)
    perform_passthrough_child_merge(store, parent, child, graph)
    assert_false(graph.contains_step(child))
    assert_true(graph.find_edge(other, parent) != NONE)


def test_children_merge_checks_each_pair_again() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    var parent = graph.add_step(root_step(store, "s", "{ a }"))
    var first = root_step(store, "s", "{ b }")
    first.input = selections(store, ["Query"], ["{ f(a: 1) }"])
    var second = root_step(store, "s", "{ c }")
    second.input = selections(store, ["Query"], ["{ f(a: 2) }"])
    var first_index = graph.add_step(first^)
    var second_index = graph.add_step(second^)
    _ = graph.connect(root, parent)
    _ = graph.connect(parent, second_index)
    _ = graph.connect(parent, first_index)
    merge_children_with_parents(store, graph)
    # The first child's input now conflicts with the second one's.
    assert_false(graph.contains_step(first_index))
    assert_true(graph.contains_step(second_index))


def test_sibling_merge_checks_each_pair_again() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    var a = root_step(store, "s", "{ a }")
    a.input = selections(store, ["Query"], ["{ f(a: 1) }"])
    var b = root_step(store, "s", "{ b }")
    b.input = selections(store, ["Query"], ["{ g }"])
    var c = root_step(store, "s", "{ c }")
    c.input = selections(store, ["Query"], ["{ f(a: 2) }"])
    var a_index = graph.add_step(a^)
    var b_index = graph.add_step(b^)
    var c_index = graph.add_step(c^)
    _ = graph.connect(root, c_index)
    _ = graph.connect(root, b_index)
    _ = graph.connect(root, a_index)
    merge_siblings(store, graph)
    assert_false(graph.contains_step(b_index))
    assert_true(graph.contains_step(c_index))


def test_leafs_need_the_same_input_types() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var book = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a"]),
            selections(store, ["Book"], ["{ __typename id }"]),
            selections(store, ["Book"], ["{ title }"]),
        )
    )
    var film = graph.add_step(
        entity_step(
            store,
            "s",
            path(store, ["a"]),
            selections(store, ["Film"], ["{ __typename id }"]),
            selections(store, ["Film"], ["{ title }"]),
        )
    )
    assert_false(can_merge_leafs(store, graph, book, film))


def test_prune_removes_an_empty_leaf() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.QUERY)
    var root = noop_root(graph)
    var full = graph.add_step(root_step(store, "s", "{ a }"))
    var empty = root_step(store, "s")
    empty.output = selections(store, ["Query"], ["{ a }"])
    store.clear(empty.output.sets[0])
    var empty_index = graph.add_step(empty^)
    _ = graph.connect(root, full)
    _ = graph.connect(root, empty_index)
    # A step with fields but no parent and no child goes too.
    var orphan = graph.add_step(root_step(store, "s", "{ b }"))
    deduplicate_and_prune_fetch_steps(store, graph)
    assert_false(graph.contains_step(orphan))
    assert_true(graph.contains_step(full))
    assert_false(graph.contains_step(empty_index))


def test_mutation_without_a_field_position_raises() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.MUTATION)
    var root = noop_root(graph)
    _ = graph.connect(root, graph.add_step(root_step(store, "a")))
    var message = String()
    try:
        turn_mutations_into_sequence(graph)
    except e:
        message = String(e)
    assert_equal(
        message, "Expected a FetchStep with Mutation to have its order defined"
    )


def test_mutation_groups() raises:
    var store = Store()
    var graph = FetchGraph(OperationKind.MUTATION)
    var root = noop_root(graph)
    var first = graph.add_step(root_step(store, "a", position=0))
    var mixed_b = graph.add_step(root_step(store, "b", position=1))
    var mixed_c = graph.add_step(root_step(store, "c", position=1))
    var third = graph.add_step(root_step(store, "c", position=2))
    var fourth = graph.add_step(root_step(store, "c", position=3))
    var fourth_too = graph.add_step(root_step(store, "c", "{ b }", position=3))
    var shared = graph.add_step(root_step(store, "d"))
    # The root's children come newest first: positions 0, 1, 1, 2, 3.
    _ = graph.connect(root, fourth_too)
    _ = graph.connect(root, fourth)
    _ = graph.connect(root, third)
    _ = graph.connect(root, mixed_c)
    _ = graph.connect(root, mixed_b)
    _ = graph.connect(root, first)
    # The only leaf after the first field is reached from the next group
    # too, so the next group does not wait for it.
    _ = graph.connect(first, shared)
    _ = graph.connect(mixed_b, shared)
    turn_mutations_into_sequence(graph)
    assert_true(graph.find_edge(root, mixed_b) != NONE)
    # The fields of one subgraph run one after another.
    assert_true(graph.find_edge(third, fourth) != NONE)
    assert_equal(graph.find_edge(root, fourth), NONE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
