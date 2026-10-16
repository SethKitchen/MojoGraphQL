# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the policy paths that the ported upstream cases do not reach.

These cases have no upstream test file: `keyArgs` paths of directives and
variables, `keyFields` paths through arrays, `null`, a read function and a
pending entity, the root type options, deep supertypes, the compaction of
the arena, and calls on removed entities. Each expected `extract()` is the
output of Apollo Client 4.3.3 in Node.js for the same operations.
"""

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    Modifier,
)
from gql_client.policies import FieldPolicy, KeyArgs, KeyFields, TypePolicy
from std.collections import Dict
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from _helpers import assert_extract_exact, gql, json, write


def test_key_args_paths_of_directives_and_variables() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var f = FieldPolicy()
    f.key_args = KeyArgs.parse('["@connection", ["key"], "$v", "a"]')
    query_policy.fields["f"] = f^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        (
            'query ($v: Int) { x: f(a: 1) @other @connection(key: "k") y: f(a:'
            " 2) @connection z: f(a: 3) }"
        ),
        '{"x": 1, "y": 2, "z": 3}',
        '{"v": 5}',
    )
    _ = write(cache, "{ w: f(a: 4) }", '{"w": 4}')
    var kept = '"f:{\\"@connection\\":{\\"key\\":\\"k\\"},\\"$v\\":5,\\"a\\":1}":1,"f:{\\"@connection\\":{\\"key\\":null},\\"$v\\":5,\\"a\\":2}":2,"f:{\\"$v\\":5,\\"a\\":3}":3'
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query",' + kept + ',"f:{\\"a\\":4}":4}}',
    )
    assert_true(cache.evict(field_name="f", args=json('{"a": 4}')))
    assert_extract_exact(
        cache, '{"ROOT_QUERY":{"__typename":"Query",' + kept + "}}"
    )


def read_owner(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read(_, { toReference }) { return toReference("Person:1") }`."""
    return options.to_reference("Person:1")


def test_a_key_path_through_a_read_function_reference() raises:
    var config = InMemoryCacheConfig()
    var book = TypePolicy()
    book.key_fields = KeyFields.parse('["owner", ["name"]]')
    book.fields["owner"] = FieldPolicy(read_owner)
    config.type_policies["Book"] = book^
    var cache = InMemoryCache(config)
    cache.restore(json('{"Person:1": {"__typename": "Person", "name": "P"}}'))
    _ = write(
        cache,
        "{ book { title } }",
        '{"book": {"__typename": "Book", "title": "t"}}',
    )
    assert_extract_exact(
        cache,
        '{"Person:1":{"__typename":"Person","name":"P"},"Book:{\\"owner\\":{\\"name\\":\\"P\\"}}":{"__typename":"Book","title":"t","owner":{"name":"P"}},"ROOT_QUERY":{"__typename":"Query","book":{"__ref":"Book:{\\"owner\\":{\\"name\\":\\"P\\"}}"}}}',
    )


def test_a_key_path_through_a_pending_entity_reads_the_store() raises:
    var config = InMemoryCacheConfig()
    var book = TypePolicy()
    book.key_fields = KeyFields.parse('["author", ["name"]]')
    config.type_policies["Book"] = book^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "{ a: author { id name } }",
        '{"a": {"__typename": "Author", "id": 1, "name": "N"}}',
    )
    _ = write(
        cache,
        "{ book { title author { id } } }",
        (
            '{"book": {"__typename": "Book", "title": "t", "author":'
            ' {"__typename": "Author", "id": 1}}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Author:1":{"__typename":"Author","id":1,"name":"N"},"ROOT_QUERY":{"__typename":"Query","author":{"__ref":"Author:1"},"book":{"__ref":"Book:{\\"author\\":{\\"name\\":\\"N\\"}}"}},"Book:{\\"author\\":{\\"name\\":\\"N\\"}}":{"__typename":"Book","title":"t","author":{"__ref":"Author:1","name":"N"}}}',
    )


def test_key_paths_through_arrays_and_null_and_no_paths() raises:
    var config = InMemoryCacheConfig()
    var tag = TypePolicy()
    tag.key_fields = KeyFields.parse('["tags", ["name"], "owner", ["name"]]')
    config.type_policies["Tag"] = tag^
    var empty = TypePolicy()
    empty.key_fields = KeyFields.parse("[]")
    config.type_policies["E"] = empty^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "{ t { tags { name } owner { name } } e { x } }",
        (
            '{"t": {"__typename": "Tag", "tags": [{"name": "a"}, {"name":'
            ' "b"}], "owner": null}, "e": {"__typename": "E", "x": 1}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Tag:{\\"tags\\":{\\"name\\":[\\"a\\",\\"b\\"]},\\"owner\\":{\\"name\\":null}}":{"__typename":"Tag","tags":[{"name":"a"},{"name":"b"}],"owner":{"name":null}},"E:{}":{"__typename":"E","x":1},"ROOT_QUERY":{"__typename":"Query","t":{"__ref":"Tag:{\\"tags\\":{\\"name\\":[\\"a\\",\\"b\\"]},\\"owner\\":{\\"name\\":null}}"},"e":{"__ref":"E:{}"}}}',
    )


def test_root_type_options() raises:
    var same = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    query_policy.query_type = True
    same.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(same)
    assert_equal(cache.policies.query_typename, "Query")
    var twice = InMemoryCacheConfig()
    var root = TypePolicy()
    root.query_type = True
    twice.type_policies["Root"] = root^
    var other = TypePolicy()
    other.query_type = True
    twice.type_policies["Other"] = other^
    with assert_raises(
        contains="Cannot change root Query __typename more than once"
    ):
        _ = InMemoryCache(twice)


def test_deep_supertypes_and_fuzzy_and_empty_subtypes() raises:
    var config = InMemoryCacheConfig()
    var top: List[String] = ["A"]
    config.possible_types["Top"] = top^
    var a: List[String] = ["B"]
    config.possible_types["A"] = a^
    var c: List[String] = [".*Z"]
    config.possible_types["C"] = c^
    var d = List[String]()
    config.possible_types["D"] = d^
    var e: List[String] = [".*Z"]
    config.possible_types["E"] = e^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        (
            "{ b { ... on C { x } ... on D { y } ... on Top { z } ... on Gone {"
            " w } } }"
        ),
        '{"b": {"__typename": "B", "x": 1, "y": 2, "z": 3, "w": 4}}',
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","b":{"__typename":"B","z":3}}}',
    )


def test_a_type_policy_added_twice_keeps_its_field_policy() raises:
    var cache = InMemoryCache()
    var first = Dict[String, TypePolicy]()
    var policy = TypePolicy()
    var field = FieldPolicy()
    field.key_args = KeyArgs.disabled()
    policy.fields["f"] = field^
    first["T"] = policy.copy()
    cache.policies.add_type_policies(first)
    _ = cache.policies.get_type_policy("T")
    cache.policies.add_type_policies(first)
    _ = cache.policies.get_type_policy("T")
    assert_equal(len(cache.policies.fields), 1)


def test_the_arena_is_compacted_and_keeps_the_data() raises:
    var cache = InMemoryCache()
    var data = String('{"items": [')
    var index = 0
    while index < 50:
        if index > 0:
            data += ","
        data += String('{"__typename": "I", "id": ', index, ', "v": [1, 2, 3]}')
        index += 1
    data += "]}"
    var round = 0
    while round < 30:
        _ = write(cache, "{ items { id v } }", data)
        round += 1
    assert_true(cache.live > 0)
    assert_true(len(cache.values.nodes) < 4200 + 2 * cache.live)
    var text = cache.extract()
    assert_true(text.startswith('{"I:0":{"__typename":"I","id":0,"v":[1,2,3]}'))


def test_calls_on_removed_entities() raises:
    var cache = InMemoryCache()
    _ = write(cache, "{ a { id } }", '{"a": {"__typename": "A", "id": 1}}')
    assert_true(cache.evict("A:1"))
    assert_false(cache.evict("A:1"))
    assert_false(cache.modify(Dict[String, Modifier](), "A:1"))


def test_extract_keeps_index_keys_that_are_in_order() raises:
    var cache = InMemoryCache()
    cache.restore(json('{"1": {"1": 1, "2": 2}, "2": {"a": 1}}'))
    assert_extract_exact(cache, '{"1":{"1":1,"2":2},"2":{"a":1}}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
