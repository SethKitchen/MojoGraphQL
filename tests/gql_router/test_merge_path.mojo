# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for merge paths and their text.

Upstream `bin/router/src/query_planner/ast/merge_path.rs` has no tests of
its own for `Display`. The expected texts are upstream `Display`.
"""

from gql_router.ast import NONE, Cond
from gql_router.merge_path import MergePath, Segment, SegmentKind
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_segment_kinds_are_valid() raises:
    assert_true(SegmentKind.TYPE_CONDITION.is_valid())
    assert_false(SegmentKind(3).is_valid())


def test_text_writes_conditions_and_type_sets() raises:
    var store = Store()
    var s = store.sym("s")
    var i = store.sym("i")
    var types = store.type_set([store.sym("B"), store.sym("A")])
    var path = (
        MergePath()
        .push(Segment.field(store.sym("a"), NONE, NONE, Cond(s, i)))
        .push(Segment.list())
        .push(Segment.type_condition(types, Cond(NONE, i)))
        .push(
            Segment.field(store.sym("b"), store.sym("k"), NONE, Cond(s, NONE))
        )
        .push(Segment.type_condition(store.type_set(List[Int]()), Cond.none()))
    )
    assert_equal(
        path.text(store),
        (
            "a @skip(if: $s) @include(if: $i).@.|[A|B] @include(if: $i).k"
            " @skip(if: $s).|[]"
        ),
    )
    assert_equal(
        path.without_type_castings().text(store),
        "a @skip(if: $s) @include(if: $i).@.k @skip(if: $s)",
    )
    assert_equal(len(MergePath().without_type_castings()), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
