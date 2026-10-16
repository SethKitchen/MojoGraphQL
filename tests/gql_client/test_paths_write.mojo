# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the write and read paths that the ported upstream cases do not
reach.

These cases have no upstream test file. Each expected `extract()` and diff
is the output of Apollo Client 4.3.3 in Node.js for the same operations.
"""

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyFieldsContext,
)
from gql_client.policies import FieldPolicy, KeyFields, Merge, TypePolicy
from gql_client.values import NULL_VALUE
from gql_json.value import JsonDocument
from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from _helpers import (
    assert_extract_exact,
    gql,
    json,
    text_of,
    write,
)


def concat_tags(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`merge(e = [], i) { return [...e, ...i] }`."""
    ref values = options.cache[].values
    var items = values.array_items(existing)
    items.extend(Span(values.array_items(incoming)))
    return values.add_array(items)


def test_an_entity_under_a_merge_type_with_a_merge_field() raises:
    var config = InMemoryCacheConfig()
    var book = TypePolicy()
    book.merge = Merge(True)
    var tags = FieldPolicy()
    tags.merge = Merge(concat_tags)
    book.fields["tags"] = tags^
    config.type_policies["Book"] = book^
    var cache = InMemoryCache(config)
    var query = "{ book { id title tags } }"
    _ = write(
        cache,
        query,
        (
            '{"book": {"__typename": "Book", "id": 1, "title": "a", "tags":'
            ' ["x"]}}'
        ),
    )
    _ = write(
        cache,
        query,
        (
            '{"book": {"__typename": "Book", "id": 1, "title": "b", "tags":'
            ' ["y"]}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Book:1":{"__typename":"Book","id":1,"title":"b","tags":["x","y"]},"ROOT_QUERY":{"__typename":"Query","book":{"__ref":"Book:1"}}}',
    )


def test_a_scalar_where_a_selection_set_is() raises:
    var cache = InMemoryCache()
    _ = write(cache, "{ a { b } }", '{"a": 5}')
    assert_extract_exact(cache, '{"ROOT_QUERY":{"__typename":"Query","a":{}}}')


def test_a_typename_from_an_inline_fragment() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "{ a { ... on T { t: __typename x } } }",
        '{"a": {"t": "T", "x": 1}}',
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__typename":"T","x":1}}}',
    )


def test_a_typename_that_is_not_a_string() raises:
    var cache = InMemoryCache()
    _ = write(
        cache, "{ a { __typename x } }", '{"a": {"__typename": 5, "x": 1}}'
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__typename":5,"x":1}}}',
    )


def _fuzzy_cache() raises -> InMemoryCache:
    """A cache whose `S` has the fuzzy subtype `X.*`."""
    var config = InMemoryCacheConfig()
    var subtypes: List[String] = ["X.*"]
    config.possible_types["S"] = subtypes^
    return InMemoryCache(config)


def test_a_fuzzy_match_checks_the_shape_of_the_result() raises:
    var query = "{ a { ... on S { items { id } n @skip(if: true) o { p } } } }"
    var matched = _fuzzy_cache()
    _ = write(
        matched,
        query,
        '{"a": {"__typename": "Xa", "items": [{"id": 1}], "o": {"p": 1}}}',
    )
    assert_extract_exact(
        matched,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__typename":"Xa","items":[{"id":1}],"o":{"p":1}}}}',
    )
    var scalar_item = _fuzzy_cache()
    _ = write(
        scalar_item,
        query,
        '{"a": {"__typename": "Xb", "items": [5], "o": {"p": 1}}}',
    )
    assert_extract_exact(
        scalar_item,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__typename":"Xb"}}}',
    )
    var missing = _fuzzy_cache()
    _ = write(
        missing, query, '{"a": {"__typename": "Xc", "items": [{"id": 1}]}}'
    )
    assert_extract_exact(
        missing, '{"ROOT_QUERY":{"__typename":"Query","a":{"__typename":"Xc"}}}'
    )
    var scalar_object = _fuzzy_cache()
    _ = write(
        scalar_object,
        query,
        '{"a": {"__typename": "Xd", "items": [{"id": 1}], "o": 7}}',
    )
    assert_extract_exact(
        scalar_object,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__typename":"Xd"}}}',
    )
    # No result object: the fragment of a fuzzy type cannot match.
    var empty = _fuzzy_cache()
    _ = empty.write_query(gql("{ ... on S { a } }"), JsonDocument())
    assert_extract_exact(empty, '{"ROOT_QUERY":{"__typename":"Query"}}')


def test_a_fragment_id_with_no_type() raises:
    var cache = InMemoryCache()
    var fragment = gql("fragment F on T { a }")
    _ = cache.write_fragment(fragment, json('{"a": 1}'), "Unknown:1")
    assert_extract_exact(
        cache, '{"Unknown:1":{},"__META":{"extraRootIds":["Unknown:1"]}}'
    )
    _ = cache.write_fragment(fragment, json('{"a": 1}'), "Unknown:1")
    assert_extract_exact(
        cache, '{"Unknown:1":{},"__META":{"extraRootIds":["Unknown:1"]}}'
    )


def pair(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`merge(e, i) { return [e === undefined ? null : e, i] }`."""
    ref values = options.cache[].values
    var items = List[Int]()
    items.append(NULL_VALUE if existing < 0 else existing)
    items.append(incoming)
    assert_equal(options.read_field("anything"), -1)
    return values.add_array(items)


def test_merge_trees_of_arrays_and_objects() raises:
    var config = InMemoryCacheConfig()
    var x = TypePolicy()
    var y = FieldPolicy()
    y.merge = Merge(pair)
    x.fields["y"] = y^
    config.type_policies["X"] = x^
    var cache = InMemoryCache(config)
    var query = "{ x { y } }"
    _ = write(cache, query, '{"x": [{"__typename": "X", "y": 1}]}')
    _ = write(cache, query, '{"x": {"__typename": "X", "y": 2}}')
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","x":{"__typename":"X","y":[null,2]}}}',
    )
    _ = write(cache, query, '{"x": [{"__typename": "X", "y": 3}]}')
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","x":[{"__typename":"X","y":[null,3]}]}}',
    )


def test_store_names_of_arguments() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        (
            "{ f(a: null) g(a: 1, a: 2) h(o: {x: 1, x: 2}) i(s: 1)"
            ' @connection(key: "k", filter: ["b", "a"]) }'
        ),
        '{"f": 1, "g": 2, "h": 3, "i": 4}',
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","f({\\"a\\":null})":1,"g({\\"a\\":2})":2,"h({\\"o\\":{\\"x\\":2}})":3,"i:k":4}}',
    )


def test_document_errors() raises:
    var cache = InMemoryCache()
    with assert_raises(
        contains=(
            "`__typename` is a forbidden field alias name in the selection"
            ' set for field `a.name` in query "Named".'
        )
    ):
        _ = cache.diff(gql("query Named { a { __typename: name } }"))
    with assert_raises(
        contains=(
            "`__ac_x` is a forbidden field alias name in the selection set"
            ' for field `name` in query "(anonymous)".'
        )
    ):
        _ = cache.diff(gql("{ __ac_x: name }"))
    with assert_raises(
        contains="Incorrect number of arguments for the @include directive."
    ):
        _ = write(cache, "{ a @include(if: true, x: 1) }", '{"a": 1}')
    with assert_raises(contains="Must contain a query definition."):
        _ = cache.write_query(gql("fragment F on T { a }"), json("{}"))
    with assert_raises(contains="Must contain a query definition."):
        _ = cache.diff(gql("mutation { a }"))
    with assert_raises(contains="Could not identify object {}"):
        _ = cache.write_fragment(gql("fragment F on T { a }"), JsonDocument())


def read_typed(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read() { return { __typename: "T", id: 1 } }`."""
    return options.cache[].values.from_json(
        json('{"__typename": "T", "id": 1}'), 0
    )


def read_query_object(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`read() { return { __typename: "Query" } }`."""
    return options.cache[].values.from_json(json('{"__typename": "Query"}'), 0)


def test_missing_messages_name_the_object_by_its_id() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    query_policy.fields["r"] = FieldPolicy(read_typed)
    query_policy.fields["q"] = FieldPolicy(read_query_object)
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    var diff = cache.diff(gql("{ r { zz } q { yy } }"))
    assert_equal(
        text_of(diff.result.value()), '{"r":{"__typename":"T"},"q":{}}'
    )
    assert_equal(
        text_of(diff.missing.value().missing),
        (
            '{"r":{"zz":"Can\'t find field \'zz\' on T:1'
            ' object"},"q":{"yy":"Can\'t find field \'yy\' on ROOT_QUERY'
            ' object"}}'
        ),
    )


def test_an_array_drops_what_cannot_be_read() raises:
    var cache = InMemoryCache()
    cache.restore(
        json('{"ROOT_QUERY": {"l": [{"__ref": "Gone"}, 5, {"a": 1}]}}')
    )
    var diff = cache.diff(gql("{ l { a } }"))
    assert_true(diff.complete)
    assert_equal(text_of(diff.result.value()), '{"l":[{"a":1}]}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
