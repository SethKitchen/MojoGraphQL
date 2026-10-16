# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Byte-exact `extract` and read results, against Apollo Client 4.3.3.

No upstream test file holds these scenarios. Each expected text is the
`JSON.stringify` output of Node.js Apollo Client 4.3.3 (with graphql
16.14.2) for the same operations: the key order of every object, the
order of the entities, the number forms and the string escapes must all
be the same.

The scenarios cover normalization, arguments and variables with default
values, aliases, `@connection` with `filter`, nested entities, arrays with
nulls and nested arrays, nested `keyFields` paths, `merge: true` type
policies, `writeFragment` ids and `__META.extraRootIds`, `restore`,
`evict` of an entity, of a field and of a field with arguments, `gc`,
`modify`, number and string forms, and `_id` and object ids.
"""

from std.collections import Dict

from gql_client.cache import (
    InMemoryCache,
    InMemoryCacheConfig,
    Modifier,
    ModifierDetails,
)
from gql_client.policies import KeyFields, Merge, TypePolicy
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _helpers import (
    assert_extract_exact,
    assert_read_exact,
    gql,
    json,
    text_of,
    write,
)


def test_normalizes_nested_entities() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "{ hero { __typename id name friends { __typename id name } } }",
        (
            '{"hero": {"__typename": "Droid", "id": "2001", "name": "R2-D2",'
            ' "friends": [{"__typename": "Human", "id": "1000", "name":'
            ' "Luke"}, {"__typename": "Human", "id": "1002", "name": "Han"}]}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Human:1000":{"__typename":"Human","id":"1000","name":"Luke"},"Human:1002":{"__typename":"Human","id":"1002","name":"Han"},"Droid:2001":{"__typename":"Droid","id":"2001","name":"R2-D2","friends":[{"__ref":"Human:1000"},{"__ref":"Human:1002"}]},"ROOT_QUERY":{"__typename":"Query","hero":{"__ref":"Droid:2001"}}}',
    )
    assert_read_exact(
        cache,
        gql("{ hero { name friends { name } } }"),
        '{"hero":{"__typename":"Droid","name":"R2-D2","friends":[{"__typename":"Human","name":"Luke"},{"__typename":"Human","name":"Han"}]}}',
    )


def test_arguments_variables_and_default_values() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        (
            "query Q($ep: Episode, $n: Int = 3) { hero(episode: $ep, first: $n,"
            ' filter: { b: [2, 1], a: "x" }) { __typename id name } }'
        ),
        '{"hero": {"__typename": "Human", "id": "1000", "name": "Luke"}}',
        '{"ep": "EMPIRE"}',
    )
    assert_extract_exact(
        cache,
        '{"Human:1000":{"__typename":"Human","id":"1000","name":"Luke"},"ROOT_QUERY":{"__typename":"Query","hero({\\"episode\\":\\"EMPIRE\\",\\"filter\\":{\\"a\\":\\"x\\",\\"b\\":[2,1]},\\"first\\":3})":{"__ref":"Human:1000"}}}',
    )


def test_aliases() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        (
            "{ a: item(id: 1) { __typename id label: name } b: item(id: 2) {"
            " __typename id label: name } }"
        ),
        (
            '{"a": {"__typename": "Item", "id": 1, "label": "one"}, "b":'
            ' {"__typename": "Item", "id": 2, "label": "two"}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Item:1":{"__typename":"Item","id":1,"name":"one"},"Item:2":{"__typename":"Item","id":2,"name":"two"},"ROOT_QUERY":{"__typename":"Query","item({\\"id\\":1})":{"__ref":"Item:1"},"item({\\"id\\":2})":{"__ref":"Item:2"}}}',
    )
    assert_read_exact(
        cache,
        gql("{ b: item(id: 2) { name } a: item(id: 1) { title: name } }"),
        '{"b":{"__typename":"Item","name":"two"},"a":{"__typename":"Item","title":"one"}}',
    )


def test_connection_with_a_filter() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        (
            '{ feed(type: "top", offset: 0, limit: 2) @connection(key: "feed",'
            ' filter: ["type"]) { id } other(x: 1) @connection(key: "plain") {'
            " id } }"
        ),
        '{"feed": [{"id": 1}, {"id": 2}], "other": [{"id": 3}]}',
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","feed({\\"type\\":\\"top\\"})":[{"id":1},{"id":2}],"other:plain":[{"id":3}]}}',
    )


def test_arrays_with_nulls_and_nested_arrays() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        (
            "{ list { __typename id children { __typename id v } } grid {"
            " __typename id } }"
        ),
        (
            '{"list": [{"__typename": "N", "id": 1, "children": [null,'
            ' {"__typename": "C", "id": 9, "v": 1.50}]}, null, {"__typename":'
            ' "N", "id": 2, "children": []}], "grid": [[{"__typename": "G",'
            ' "id": "x"}, null], []]}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"C:9":{"__typename":"C","id":9,"v":1.5},"N:1":{"__typename":"N","id":1,"children":[null,{"__ref":"C:9"}]},"N:2":{"__typename":"N","id":2,"children":[]},"G:x":{"__typename":"G","id":"x"},"ROOT_QUERY":{"__typename":"Query","list":[{"__ref":"N:1"},null,{"__ref":"N:2"}],"grid":[[{"__ref":"G:x"},null],[]]}}',
    )
    assert_read_exact(
        cache,
        gql("{ list { id children { v } } grid { id } }"),
        '{"list":[{"__typename":"N","id":1,"children":[null,{"__typename":"C","v":1.5}]},null,{"__typename":"N","id":2,"children":[]}],"grid":[[{"__typename":"G","id":"x"},null],[]]}',
    )


def test_nested_key_fields() raises:
    var config = InMemoryCacheConfig()
    var book = TypePolicy()
    book.key_fields = KeyFields.parse('["title", "author", ["name", "birth"]]')
    config.type_policies["Book"] = book^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "{ book { __typename title year author { __typename name birth } } }",
        (
            '{"book": {"__typename": "Book", "title": "B", "year": 1999,'
            ' "author": {"__typename": "Person", "name": "N", "birth": 1950}}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Book:{\\"title\\":\\"B\\",\\"author\\":{\\"name\\":\\"N\\",\\"birth\\":1950}}":{"__typename":"Book","title":"B","year":1999,"author":{"__typename":"Person","name":"N","birth":1950}},"ROOT_QUERY":{"__typename":"Query","book":{"__ref":"Book:{\\"title\\":\\"B\\",\\"author\\":{\\"name\\":\\"N\\",\\"birth\\":1950}}"}}}',
    )
    var id = cache.identify(
        json(
            '{"__typename": "Book", "title": "B", "author": {"birth": 1950,'
            ' "name": "N"}}'
        )
    )
    assert_equal(
        id.value(), 'Book:{"title":"B","author":{"name":"N","birth":1950}}'
    )


def _settings_cache(merge: Bool) raises -> InMemoryCache:
    """A cache whose `Settings` policy has `merge: true`, or no policy."""
    var config = InMemoryCacheConfig()
    if merge:
        var settings = TypePolicy()
        settings.merge = Merge(True)
        config.type_policies["Settings"] = settings^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "{ settings { __typename theme } }",
        '{"settings": {"__typename": "Settings", "theme": "dark"}}',
    )
    _ = write(
        cache,
        "{ settings { __typename lang } }",
        '{"settings": {"__typename": "Settings", "lang": "en"}}',
    )
    return cache^


def test_merge_true_type_policy() raises:
    var cache = _settings_cache(True)
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","settings":{"__typename":"Settings","theme":"dark","lang":"en"}}}',
    )


def test_unidentified_objects_are_replaced_without_merge() raises:
    var cache = _settings_cache(False)
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","settings":{"__typename":"Settings","lang":"en"}}}',
    )


def test_write_fragment_ids_are_extra_root_ids() raises:
    var cache = InMemoryCache()
    _ = cache.write_fragment(
        gql("fragment F on Item { name }"),
        json('{"__typename": "Item", "name": "two"}'),
        "Item:2",
    )
    _ = cache.write_fragment(
        gql("fragment F on Item { name }"),
        json('{"__typename": "Item", "name": "ten"}'),
        "Item:10",
    )
    var id = cache.write_fragment(
        gql("fragment F on Item { id name }"),
        json('{"__typename": "Item", "id": "a", "name": "A"}'),
    )
    assert_equal(id, "Item:a")
    assert_extract_exact(
        cache,
        '{"Item:2":{"__typename":"Item","name":"two"},"Item:10":{"__typename":"Item","name":"ten"},"Item:a":{"__typename":"Item","id":"a","name":"A"},"__META":{"extraRootIds":["Item:10","Item:2","Item:a"]}}',
    )


def test_restore_then_extract() raises:
    var cache = InMemoryCache()
    cache.restore(
        json(
            '{"B:1": {"__typename": "B", "id": 1, "x": {"__ref": "A:1"}},'
            ' "ROOT_QUERY": {"__typename": "Query", "b": {"__ref": "B:1"}},'
            ' "A:1": {"__typename": "A", "id": 1}, "__META": {"extraRootIds":'
            ' ["Z", "A:1"]}}'
        )
    )
    assert_extract_exact(
        cache,
        '{"B:1":{"__typename":"B","id":1,"x":{"__ref":"A:1"}},"ROOT_QUERY":{"__typename":"Query","b":{"__ref":"B:1"}},"A:1":{"__typename":"A","id":1},"__META":{"extraRootIds":["A:1","Z"]}}',
    )
    assert_read_exact(
        cache,
        gql("{ b { id x { id } } }"),
        '{"b":{"__typename":"B","id":1,"x":{"__typename":"A","id":1}}}',
    )


def test_evict_entities_fields_and_field_arguments() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "{ a { __typename id } b(x: 1) c(x: 1) c2: c(x: 2) d }",
        '{"a": {"__typename": "A", "id": 1}, "b": 1, "c": 2, "c2": 3, "d": 4}',
    )
    assert_true(cache.evict(String("A:1")))
    assert_true(cache.evict(None, "c", json('{"x": 2}')))
    assert_true(cache.evict(None, "b"))
    assert_false(cache.evict(String("Nope:1")))
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__ref":"A:1"},"c({\\"x\\":1})":2,"d":4}}',
    )


def test_gc_removes_unreachable_entities() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "{ a { __typename id child { __typename id } } }",
        (
            '{"a": {"__typename": "A", "id": 1, "child": {"__typename": "C",'
            ' "id": 1}}}'
        ),
    )
    _ = write(
        cache, "{ a { __typename id } }", '{"a": {"__typename": "A", "id": 2}}'
    )
    _ = cache.write_fragment(
        gql("fragment K on K { v }"), json('{"__typename": "K", "v": 1}'), "K:1"
    )
    var removed = cache.gc()
    assert_equal(len(removed), 2)
    assert_equal(removed[0], "C:1")
    assert_equal(removed[1], "A:1")
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__ref":"A:2"}},"A:2":{"__typename":"A","id":2},"K:1":{"__typename":"K","v":1},"__META":{"extraRootIds":["K:1"]}}',
    )


def add_one(value: Int, mut details: ModifierDetails) raises -> Int:
    """`count(v) { return v + 1; }`."""
    ref values = details.cache[].values
    return values.add_int(Int(atol(values.text(value))) + 1)


def drop_first(value: Int, mut details: ModifierDetails) raises -> Int:
    """`list(items, { readField }) { return items.filter((r) =>
    readField("id", r) !== 1); }`."""
    ref values = details.cache[].values
    var items = List[Int]()
    var index = 0
    while index < values.length(value):
        var item = values.item(value, index)
        var id = details.read_field_from("id", item)
        if String(values.text(id)) != "1":
            items.append(item)
        index += 1
    return values.add_array(items)


def test_modify() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "{ count list { __typename id } }",
        (
            '{"count": 1, "list": [{"__typename": "I", "id": 1}, {"__typename":'
            ' "I", "id": 2}]}'
        ),
    )
    var fields = Dict[String, Modifier]()
    fields["count"] = add_one
    fields["list"] = drop_first
    assert_true(cache.modify(fields))
    assert_extract_exact(
        cache,
        '{"I:1":{"__typename":"I","id":1},"I:2":{"__typename":"I","id":2},"ROOT_QUERY":{"__typename":"Query","count":2,"list":[{"__ref":"I:2"}]}}',
    )


def test_number_and_string_forms() raises:
    var cache = InMemoryCache()
    var query = '{ s(t: "e\\u00e9") n(v: 1.50) big e }'
    _ = write(
        cache,
        query,
        (
            '{"s": "a\\"b\\\\c\\n\\u0001é", "n": 1e21, "big":'
            ' 12345678901234567890, "e": -0.0}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","s({\\"t\\":\\"eé\\"})":"a\\"b\\\\c\\n\\u0001é","n({\\"v\\":1.5})":1e+21,"big":12345678901234567000,"e":0}}',
    )
    assert_read_exact(
        cache,
        gql('{ s(t: "e\\u00e9") n(v: 1.5) big e }'),
        '{"s":"a\\"b\\\\c\\n\\u0001é","n":1e+21,"big":12345678901234567000,"e":0}',
    )


def test_underscore_ids_and_object_ids() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "{ x { __typename _id v } y { __typename id _id } }",
        (
            '{"x": {"__typename": "X", "_id": "u", "v": true}, "y":'
            ' {"__typename": "Y", "id": {"a": 1}, "_id": 3}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"X:u":{"__typename":"X","_id":"u","v":true},"Y:{\\"a\\":1}":{"__typename":"Y","id":{"a":1},"_id":3},"ROOT_QUERY":{"__typename":"Query","x":{"__ref":"X:u"},"y":{"__ref":"Y:{\\"a\\":1}"}}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
