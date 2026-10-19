# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the fetch rewrites on the response arena,
`gql_router.exec_rewrites`.

The cases follow `FetchRewriteExt::rewrite`, `KeyRenamer::apply_path` and
`ValueSetter::apply_path` of Hive Router `1a29df9`
`bin/router/src/executor/execution/rewrites.rs`, which has no tests of its
own: a key renamer, a value setter, lists, type conditions and missing
fields.
"""

from gql_json.parser import parse
from gql_json.writer import stringify
from gql_router.exec_rewrites import apply_rewrite
from gql_router.fetch_step import FetchNodePathSegment, FetchRewrite
from gql_router.schema_metadata import PossibleTypes
from gql_router.store import Store
from std.testing import TestSuite, assert_equal


def _key(mut store: Store, name: String) -> FetchNodePathSegment:
    return FetchNodePathSegment(True, store.sym(name), 0)


def _types(mut store: Store, name: String) -> FetchNodePathSegment:
    var types: List[Int] = [store.sym(name)]
    return FetchNodePathSegment(False, 0, store.type_set(types))


def _run(
    mut store: Store, rewrite: FetchRewrite, json: String
) raises -> String:
    var document = parse(json)
    var possible = PossibleTypes()
    possible.map["Media"] = {"Book"}
    apply_rewrite(store, possible, rewrite, document, document.root)
    return stringify(document, document.root)


def test_a_key_renamer_renames_the_last_field() raises:
    var store = Store()
    var path: List[FetchNodePathSegment] = [_key(store, "a"), _key(store, "b")]
    var rewrite = FetchRewrite(False, path^, store.sym("c"))
    assert_equal(
        _run(store, rewrite, '{"a":[{"b":1},{"x":2},3],"b":4}'),
        '{"a":[{"c":1},{"x":2},3],"b":4}',
    )
    var a: List[FetchNodePathSegment] = [_key(store, "a")]
    var same = FetchRewrite(False, a^, store.sym("a"))
    assert_equal(_run(store, same, '{"a":1}'), '{"a":1}')


def test_type_conditions_select_the_objects() raises:
    var store = Store()
    var path: List[FetchNodePathSegment] = [_types(store, "Media"), _key(store, "title")]
    var rewrite = FetchRewrite(False, path^, store.sym("name"))
    assert_equal(
        _run(
            store,
            rewrite,
            '[{"__typename":"Book","title":"x"},'
            + '{"__typename":"Movie","title":"y"},{"title":"z"}]',
        ),
        '[{"__typename":"Book","name":"x"},'
        + '{"__typename":"Movie","title":"y"},{"name":"z"}]',
    )


def test_a_value_setter_replaces_the_value() raises:
    var store = Store()
    var path: List[FetchNodePathSegment] = [_types(store, "Book"), _key(store, "__typename")]
    var rewrite = FetchRewrite(True, path^, store.sym("Media"))
    assert_equal(
        _run(store, rewrite, '[{"__typename":"Book"},{"__typename":"Movie"}]'),
        '[{"__typename":"Media"},{"__typename":"Movie"}]',
    )
    var root = FetchRewrite(True, List[FetchNodePathSegment](), store.sym("v"))
    assert_equal(_run(store, root, "1"), '"v"')


def test_a_missing_field_or_a_short_value_changes_nothing() raises:
    var store = Store()
    var a: List[FetchNodePathSegment] = [_key(store, "a")]
    var rewrite = FetchRewrite(False, a^, store.sym("b"))
    assert_equal(_run(store, rewrite, '{"x":1}'), '{"x":1}')
    assert_equal(_run(store, rewrite, '"text"'), '"text"')
    var empty = FetchRewrite(False, List[FetchNodePathSegment](), store.sym("b"))
    assert_equal(_run(store, empty, '{"a":1}'), '{"a":1}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
