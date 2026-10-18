# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the selection helpers of the fetch graph optimizer.

Upstream has no tests of its own for `read_as_written` and the rewrite path
of a merge path. The expected texts are upstream `Display`.
"""

from gql_router.ast import NONE, Cond
from gql_router.merge_path import MergePath, Segment
from gql_router.normalize import selection_set_from_text
from gql_router.selection_set import set_text
from gql_router.selection_tools import fetch_node_path, read_as_written
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_read_as_written_swaps_alias_and_name_at_every_depth() raises:
    var store = Store()
    var set = selection_set_from_text(
        store, "{ price: alias0 id ... on Cat { a: b } ...Rest }"
    )
    read_as_written(store, set)
    assert_equal(
        set_text(store, set), "{alias0: price id ...on Cat{b: a} ...Rest}"
    )


def test_fetch_node_path_keeps_fields_and_type_conditions() raises:
    var store = Store()
    assert_equal(len(fetch_node_path(store, MergePath())), 0)
    var types = store.single_type_set(store.sym("Cat"))
    var path = (
        MergePath()
        .push(Segment.field(store.sym("a"), store.sym("k"), NONE, Cond.none()))
        .push(Segment.list())
        .push(Segment.type_condition(types, Cond.none()))
    )
    var segments = fetch_node_path(store, path)
    assert_equal(len(segments), 2)
    assert_true(segments[0].is_key)
    assert_equal(store.name(segments[0].key), "k")
    assert_false(segments[1].is_key)
    assert_equal(segments[1].types, types)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
