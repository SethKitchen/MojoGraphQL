# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for walking a response path and merging a fetch there.

The cases follow `traverse_and_callback_mut` in Hive Router.
"""

from gql_json.parser import parse
from gql_router.ast import NONE
from gql_router.plan_nodes import FlattenNodePath, PathSegment, PathSegmentKind
from gql_router.response_path import (
    merge_fetch_data,
    path_list,
    visit_response_path,
)
from gql_router.rewrite import PossibleTypes
from gql_router.store import Store
from gql_json.writer import stringify
from std.testing import TestSuite, assert_equal


def _none() -> PossibleTypes:
    return PossibleTypes(List[String](), List[List[String]]())


def _field(mut store: Store, name: String) -> PathSegment:
    return PathSegment(PathSegmentKind.FIELD, store.sym(name), NONE)


def _list() -> PathSegment:
    return PathSegment(PathSegmentKind.LIST, NONE, NONE)


def _types(mut store: Store, first: String, second: String) -> PathSegment:
    var names = List[Int]()
    names.append(store.sym(first))
    if second.byte_length() > 0:
        names.append(store.sym(second))
    return PathSegment(
        PathSegmentKind.TYPE_CONDITION, NONE, store.type_set(names^)
    )


def _path(var segments: List[PathSegment]) -> FlattenNodePath:
    return FlattenNodePath(segments^)


def test_a_list_records_an_index_for_each_item() raises:
    var store = Store()
    var data = parse('{"items":[{"id":"1"},{"id":"2"}]}')
    var segments = List[PathSegment]()
    segments.append(_field(store, "items"))
    segments.append(_list())
    var visit = visit_response_path(
        store, data, data.root, _path(segments^), _none()
    )
    assert_equal(path_list(visit), "items.0 items.1")


def test_two_lists_record_each_nested_item() raises:
    var store = Store()
    var data = parse(
        '{"users":[{"id":"1","posts":[{"id":"a"},{"id":"b"}]},{"id":"2","posts":[{"id":"c"}]}]}'
    )
    var segments = List[PathSegment]()
    segments.append(_field(store, "users"))
    segments.append(_list())
    segments.append(_field(store, "posts"))
    segments.append(_list())
    var visit = visit_response_path(
        store, data, data.root, _path(segments^), _none()
    )
    assert_equal(
        path_list(visit), "users.0.posts.0 users.0.posts.1 users.1.posts.0"
    )


def test_a_type_condition_does_not_leak_into_the_next_item() raises:
    var store = Store()
    var data = parse(
        '{"media":[{"__typename":"Book","pages":[{"id":"a"}]},{"__typename":"Book","pages":[{"id":"b"}]}]}'
    )
    var segments = List[PathSegment]()
    segments.append(_field(store, "media"))
    segments.append(_list())
    segments.append(_types(store, "Book", ""))
    segments.append(_field(store, "pages"))
    segments.append(_list())
    var visit = visit_response_path(
        store, data, data.root, _path(segments^), _none()
    )
    assert_equal(path_list(visit), "media.0.pages.0 media.1.pages.0")
    var book = parse('{"__typename":"Book"}')
    var both = List[PathSegment]()
    both.append(_types(store, "Book", "User"))
    var matched = visit_response_path(
        store, book, book.root, _path(both^), _none()
    )
    assert_equal(len(matched.nodes), 1)
    var magazine = parse('{"__typename":"Magazine"}')
    var cast = List[PathSegment]()
    cast.append(_types(store, "Book", "User"))
    var missed = visit_response_path(
        store, magazine, magazine.root, _path(cast^), _none()
    )
    assert_equal(len(missed.nodes), 0)


def test_a_fetch_merges_at_the_root_and_into_each_list_item() raises:
    var store = Store()
    var target = parse('{"a":1}')
    var source = parse('{"b":2}')
    merge_fetch_data(target, source, FlattenNodePath(), store, _none())
    assert_equal(stringify(target, target.root), '{"a":1,"b":2}')
    var items = parse('{"items":[{"id":"1"},{"id":"2"}]}')
    var extra = parse('{"ok":true}')
    var segments = List[PathSegment]()
    segments.append(_field(store, "items"))
    segments.append(_list())
    merge_fetch_data(items, extra, _path(segments^), store, _none())
    assert_equal(
        stringify(items, items.root),
        '{"items":[{"id":"1","ok":true},{"id":"2","ok":true}]}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
