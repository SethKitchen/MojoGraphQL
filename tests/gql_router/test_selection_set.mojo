# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the selection set algorithms.

Upstream `ast/selection_set.rs`, `ast/selection_item.rs` and
`ast/semantic_eq.rs` have no unit tests; these tests check the
comparisons, the merge and the path lookups on small sets, with spreads,
conditions and empty sets that the plan tests do not reach.
"""

from gql_router.ast import NONE, Cond, ItemKind
from gql_router.merge_path import MergePath, Segment
from gql_router.normalize import selection_set_from_text
from gql_router.selection_set import (
    entities_field,
    fields_of_same_type,
    fields_through_fragments,
    find_arguments_conflicts,
    find_by_path,
    items_are_subset_of,
    items_equal,
    merge_selection_set,
    response_keys_conflict,
    segment_selects,
    semantic_eq,
    sets_equal,
)
from gql_router.store import Store
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def _set(mut store: Store, text: String) raises -> Int:
    return selection_set_from_text(store, text)


def _child(store: Store, set: Int, index: Int) -> Int:
    return store.children(set)[index]


def test_items_equal_and_sets_equal() raises:
    var store = Store()
    var set = _set(store, "{ a ... on T { b } ...F ...F x: a }")
    var a = _child(store, set, 0)
    var fragment = _child(store, set, 1)
    var spread = _child(store, set, 2)
    assert_false(items_equal(store, a, fragment))
    assert_false(items_equal(store, spread, _child(store, set, 3)))
    assert_true(items_equal(store, a, _child(store, set, 4)))
    var longer = _set(store, "{ a b }")
    var shorter = _set(store, "{ a }")
    assert_false(sets_equal(store, longer, shorter))
    assert_false(sets_equal(store, shorter, longer))
    assert_false(sets_equal(store, longer, _set(store, "{ a c }")))
    assert_true(sets_equal(store, longer, _set(store, "{ a b }")))


def test_semantic_eq() raises:
    var store = Store()
    assert_true(
        semantic_eq(store, _set(store, "{ a a }"), _set(store, "{ a a }"))
    )
    assert_true(
        semantic_eq(store, _set(store, "{ a b }"), _set(store, "{ b a }"))
    )
    assert_false(semantic_eq(store, _set(store, "{ a }"), _set(store, "{ b }")))
    assert_false(
        semantic_eq(store, _set(store, "{ a }"), _set(store, "{ a b }"))
    )
    # A field and a fragment of the same name differ.
    assert_false(
        semantic_eq(
            store, _set(store, "{ x }"), _set(store, "{ ... on x { y } }")
        )
    )
    # Spreads compare by name.
    assert_true(
        semantic_eq(store, _set(store, "{ ...F }"), _set(store, "{ ...F }"))
    )
    assert_false(
        semantic_eq(
            store, _set(store, "{ a @skip(if: $v) }"), _set(store, "{ a }")
        )
    )
    assert_false(
        semantic_eq(
            store, _set(store, "{ a @include(if: $v) }"), _set(store, "{ a }")
        )
    )
    assert_false(
        semantic_eq(store, _set(store, "{ k: a }"), _set(store, "{ a }"))
    )
    assert_false(
        semantic_eq(store, _set(store, "{ a(x: 1) }"), _set(store, "{ a }"))
    )
    var omitted = _set(store, "{ a }")
    store.items[_child(store, omitted, 0)].omit = True
    assert_false(semantic_eq(store, omitted, _set(store, "{ a }")))
    assert_true(
        semantic_eq(
            store,
            _set(store, "{ ... on T { a } }"),
            _set(store, "{ ... on T { a } }"),
        )
    )


def test_items_are_subset_of() raises:
    var store = Store()
    assert_false(
        items_are_subset_of(
            store, _set(store, "{ ...F }"), _set(store, "{ ...F }")
        )
    )
    assert_false(
        items_are_subset_of(
            store, _set(store, "{ a @skip(if: $v) }"), _set(store, "{ a }")
        )
    )
    assert_false(
        items_are_subset_of(
            store, _set(store, "{ a @include(if: $v) }"), _set(store, "{ a }")
        )
    )
    assert_false(
        items_are_subset_of(
            store, _set(store, "{ a }"), _set(store, "{ a { b } }")
        )
    )
    assert_false(
        items_are_subset_of(
            store, _set(store, "{ a(x: 1) }"), _set(store, "{ a }")
        )
    )
    assert_true(
        items_are_subset_of(
            store,
            _set(store, "{ ... on T { a b } }"),
            _set(store, "{ ... on T { a } }"),
        )
    )
    assert_false(
        items_are_subset_of(
            store,
            _set(store, "{ ... on T { a } }"),
            _set(store, "{ ... on U { a } }"),
        )
    )
    assert_false(
        items_are_subset_of(
            store, _set(store, "{ ... on T { a } }"), _set(store, "{ a }")
        )
    )


def test_merge_selection_set() raises:
    var store = Store()
    var target = _set(store, "{ a: b }")
    with assert_raises(
        contains="Response key 'a' would hold two different fields"
    ):
        merge_selection_set(store, target, _set(store, "{ a: c }"), False)
    target = _set(store, "{ b(x: 1) }")
    with assert_raises(contains="Response key 'b'"):
        merge_selection_set(store, target, _set(store, "{ b(x: 2) }"), False)
    # Same field, other condition: kept apart.
    target = _set(store, "{ a @skip(if: $v) }")
    merge_selection_set(store, target, _set(store, "{ a }"), False)
    assert_equal(store.count(target), 2)
    target = _set(store, "{ a @include(if: $v) }")
    merge_selection_set(store, target, _set(store, "{ a }"), True)
    assert_equal(store.count(target), 2)
    # Nothing new, at the end or at the front.
    target = _set(store, "{ a }")
    merge_selection_set(store, target, _set(store, "{ a }"), False)
    merge_selection_set(store, target, _set(store, "{ a }"), True)
    assert_equal(store.count(target), 1)


def test_segment_selects_and_find_by_path() raises:
    var store = Store()
    var set = _set(store, "{ a { b } ... on T { c } }")
    var a = _child(store, set, 0)
    var fragment = _child(store, set, 1)
    var t = store.sym("T")
    var u = store.sym("U")
    assert_false(segment_selects(store, Segment.list(), a))
    assert_false(
        segment_selects(
            store, Segment.type_condition(store.type_set([t]), Cond.none()), a
        )
    )
    assert_false(
        segment_selects(
            store,
            Segment.type_condition(store.type_set([u]), Cond.none()),
            fragment,
        )
    )
    assert_true(
        segment_selects(
            store,
            Segment.type_condition(store.type_set([u, t]), Cond.none()),
            fragment,
        )
    )
    var field_a = Segment.field(store.sym("a"), NONE, NONE, Cond.none())
    var field_x = Segment.field(store.sym("x"), NONE, NONE, Cond.none())
    assert_equal(find_by_path(store, set, MergePath()), set)
    assert_equal(
        find_by_path(store, set, MergePath([field_a, Segment.list()])), a
    )
    assert_equal(find_by_path(store, set, MergePath([field_x])), NONE)
    assert_equal(find_by_path(store, set, MergePath([field_a, field_x])), NONE)


def test_find_arguments_conflicts() raises:
    var store = Store()
    var other = _set(store, "{ ...F a(x: 1) b }")
    var conflicts = find_arguments_conflicts(store, store.new_set(), other)
    assert_equal(len(conflicts), 0)
    conflicts = find_arguments_conflicts(
        store, _set(store, "{ ... on T { c } b a(x: 2) }"), other
    )
    assert_equal(len(conflicts), 1)
    assert_equal(conflicts[0][0], 2)
    assert_equal(conflicts[0][1], 1)


def test_fields_through_fragments_and_conflicts() raises:
    var store = Store()
    var out = List[Int]()
    fields_through_fragments(
        store, _set(store, "{ a ...F ... on T { b } }"), out
    )
    assert_equal(len(out), 2)
    assert_false(
        response_keys_conflict(store, _set(store, "{ a }"), store.new_set())
    )
    assert_false(
        response_keys_conflict(
            store, _set(store, "{ a }"), _set(store, "{ b }")
        )
    )
    assert_true(
        response_keys_conflict(
            store, _set(store, "{ k: a }"), _set(store, "{ k: b }")
        )
    )
    assert_true(
        response_keys_conflict(
            store, _set(store, "{ a(x: 1) }"), _set(store, "{ a }")
        )
    )
    assert_true(
        response_keys_conflict(
            store, _set(store, "{ a { k: x } }"), _set(store, "{ a { k: y } }")
        )
    )
    assert_false(
        response_keys_conflict(
            store, _set(store, "{ a { x } }"), _set(store, "{ a { x } }")
        )
    )


def test_entities_field_and_fields_of_same_type() raises:
    var store = Store()
    var set = _set(store, "{ ... on T { a } other _entities { b } }")
    assert_equal(entities_field(store, set), _child(store, set, 2))
    assert_equal(
        entities_field(store, _set(store, "{ ... on T { a } other }")), NONE
    )
    var mixed = _set(
        store, "{ a ...F ... on U { b } ... on T { c ... on T { d } } }"
    )
    var fields = fields_of_same_type(store, mixed, store.sym("T"))
    assert_equal(len(fields), 3)
    assert_equal(store.name(store.items[fields[1]].name), "c")
    assert_true(store.items[fields[2]].kind == ItemKind.FIELD)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
