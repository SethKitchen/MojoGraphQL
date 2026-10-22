# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for optimistic layers (`record_optimistic_transaction`,
`remove_optimistic`, `perform_transaction`, optimistic `modify`, `evict`,
`retain`, `release`, `extract` and `gc`), ported from Apollo Client 4.3.3
`src/cache/inmemory/__tests__/entityStore.ts` and `cache.ts`.
"""

from std.collections import Dict
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from gql_client.cache import (
    DELETE,
    InMemoryCache,
    InMemoryCacheConfig,
    Modifier,
    ModifierDetails,
)
from gql_json.writer import stringify
from _helpers import (
    assert_extract_exact,
    assert_json,
    assert_read,
    gql,
    json,
    write,
)
from _store_helpers import book_author_id, gc_text

comptime BOOK_QUERY = "query { book { title author { name } } }"


def _book_author_cache() raises -> InMemoryCache:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = book_author_id
    return InMemoryCache(config)


def _write_opt_book_1(mut cache: InMemoryCache) raises:
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "9780062698537", "title":'
            ' "The Overstory", "author": {"__typename": "Author", "name":'
            ' "Richard Powers"}}}'
        ),
    )


def _write_opt_book_2(mut cache: InMemoryCache) raises:
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "9780393242584", "title":'
            ' "The Genius of Birds", "author": {"__typename": "Author", "name":'
            ' "Jennifer Ackerman"}}}'
        ),
    )


def _modify_title_upper(value: Int, mut details: ModifierDetails) raises -> Int:
    return details.cache[].values.add_string("OPTIMISTIC TITLE")


def _delete_field(value: Int, mut details: ModifierDetails) raises -> Int:
    return DELETE


def assert_read_opt(mut cache: InMemoryCache, expected: StringSlice) raises:
    var res = cache.read_query(gql(BOOK_QUERY))
    assert_true(Bool(res))
    assert_equal(stringify(res.value(), res.value().root), String(expected))


def test_optimistic_updates_layers_and_remove() raises:
    var cache = _book_author_cache()
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "0735211280", "title":'
            ' "Spineless", "author": {"__typename": "Author", "name":'
            ' "Juli Berwald"}}}'
        ),
    )
    cache.record_optimistic_transaction(_write_opt_book_1, "opt-1")
    cache.record_optimistic_transaction(_write_opt_book_2, "opt-2")

    # Optimistic read sees opt-2.
    assert_read_opt(
        cache,
        (
            '{"book":{"__typename":"Book","title":"The Genius of'
            ' Birds","author":{"__typename":"Author","name":"Jennifer'
            ' Ackerman"}}}'
        ),
    )
    # Non-optimistic read sees the root store.
    var root_read = cache.read_query(gql(BOOK_QUERY), optimistic=False)
    assert_true(Bool(root_read))
    assert_equal(
        stringify(root_read.value(), root_read.value().root),
        (
            '{"book":{"__typename":"Book","title":"Spineless","author":{"__typename":"Author","name":"Juli'
            ' Berwald"}}}'
        ),
    )

    # Removing opt-2 reveals opt-1.
    cache.remove_optimistic("opt-2")
    assert_read_opt(
        cache,
        (
            '{"book":{"__typename":"Book","title":"The'
            ' Overstory","author":{"__typename":"Author","name":"Richard'
            ' Powers"}}}'
        ),
    )
    # Removing a non-existent layer is a no-op.
    cache.remove_optimistic("unknown-layer")

    # Removing opt-1 reveals the root store.
    cache.remove_optimistic("opt-1")
    assert_read_opt(
        cache,
        (
            '{"book":{"__typename":"Book","title":"Spineless","author":{"__typename":"Author","name":"Juli'
            ' Berwald"}}}'
        ),
    )


def test_optimistic_retain_release_and_gc() raises:
    var cache = _book_author_cache()
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "0735211280", "title":'
            ' "Spineless", "author": {"__typename": "Author", "name":'
            ' "Juli Berwald"}}}'
        ),
    )
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "1603589082", "title":'
            ' "Eager", "author": {"__typename": "Author", "name": "Ben'
            ' Goldfarb"}}}'
        ),
    )
    # Retain Spineless in an optimistic layer and via optimistic=True.
    cache.record_optimistic_transaction(_write_opt_book_1, "opt-retain")
    assert_equal(cache.retain("Book:0735211280", optimistic=True), 1)
    assert_equal(cache.retain("Book:0735211280", optimistic=False), 1)
    # gc keeps entities referenced or retained in optimistic layers.
    assert_equal(gc_text(cache), "[]")
    assert_equal(cache.release("Book:0735211280", optimistic=True), 1)
    assert_equal(cache.release("Book:0735211280", optimistic=False), 0)
    assert_true("Book:0735211280" in cache.extract(optimistic=True))

    cache.remove_optimistic("opt-retain")
    assert_equal(gc_text(cache), '["Author:Juli Berwald","Book:0735211280"]')


def test_optimistic_evict_and_modify() raises:
    var cache = _book_author_cache()
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "0735211280", "title":'
            ' "Spineless", "author": {"__typename": "Author", "name":'
            ' "Juli Berwald"}}}'
        ),
    )
    cache.record_optimistic_transaction(_write_opt_book_1, "opt-mod")

    var mods = Dict[String, Modifier]()
    mods["title"] = _modify_title_upper
    assert_true(
        cache.modify(mods, String("Book:9780062698537"), optimistic=True)
    )
    assert_read_opt(
        cache,
        (
            '{"book":{"__typename":"Book","title":"OPTIMISTIC'
            ' TITLE","author":{"__typename":"Author","name":"Richard Powers"}}}'
        ),
    )

    # Delete a field in the optimistic layer.
    var del_mods = Dict[String, Modifier]()
    del_mods["title"] = _delete_field
    assert_true(
        cache.modify(del_mods, String("Book:0735211280"), optimistic=True)
    )
    var frag = gql("fragment B on Book { title }")
    assert_false(
        Bool(cache.read_fragment(frag, "Book:0735211280", optimistic=True))
    )
    assert_true(
        Bool(cache.read_fragment(frag, "Book:0735211280", optimistic=False))
    )

    # Evict an entity in the optimistic layer; root still has it.
    assert_true(cache.evict(String("Book:0735211280"), optimistic=True))
    assert_false(
        Bool(
            cache.read_fragment(
                gql("fragment B on Book { __typename }"),
                "Book:0735211280",
                optimistic=True,
            )
        )
    )
    assert_true(
        Bool(
            cache.read_fragment(
                gql("fragment B on Book { __typename }"),
                "Book:0735211280",
                optimistic=False,
            )
        )
    )

    cache.remove_optimistic("opt-mod")
    assert_read_opt(
        cache,
        (
            '{"book":{"__typename":"Book","title":"Spineless","author":{"__typename":"Author","name":"Juli'
            ' Berwald"}}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
