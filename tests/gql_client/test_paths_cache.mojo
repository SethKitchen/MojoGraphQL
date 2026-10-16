# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the cache API paths that the ported upstream cases do not reach.

These cases have no upstream test file: the policy function contexts, the
default id function called by a custom one, `identify`, `mergeObjects`
called by a merge function, `gc`, `extract` and `restore` of entities
without fields, and the store order after a delete and an add. The
expected outputs follow the upstream code paths.
"""

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyFieldsContext,
    ModifierDetails,
    Modifier,
    default_data_id_from_object,
)
from gql_client.policies import (
    FieldPolicy,
    KeyFields,
    Merge,
    TypePolicy,
)
from gql_client.values import NO_VALUE, NULL_VALUE
from std.collections import Dict
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from _helpers import (
    assert_extract,
    assert_extract_exact,
    gql,
    json,
    write,
)


def delegate_id(mut context: KeyFieldsContext) raises -> String:
    """A `dataIdFromObject` that calls `defaultDataIdFromObject`."""
    return default_data_id_from_object(context)


def test_the_default_id_function_from_a_custom_one() raises:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = delegate_id
    var cache = InMemoryCache(config)
    assert_equal(
        cache.identify(json('{"__typename": "T", "id": "a"}')).value(), "T:a"
    )
    assert_equal(
        cache.identify(
            json('{"__typename": "T", "id": null, "_id": 2}')
        ).value(),
        "T:2",
    )
    assert_equal(
        cache.identify(json('{"__typename": "T", "id": true}')).value(),
        "T:true",
    )
    assert_false(Bool(cache.identify(json('{"__typename": "T"}'))))
    assert_false(Bool(cache.identify(json('{"id": 1}'))))


def test_identify_paths() raises:
    var cache = InMemoryCache()
    assert_equal(
        cache.identify(json('{"__typename": "T", "id": "s"}')).value(), "T:s"
    )
    assert_equal(
        cache.identify(json('{"__typename": "Query"}')).value(), "ROOT_QUERY"
    )
    assert_equal(cache.identify(json('{"__ref": "X:1"}')).value(), "X:1")
    assert_false(Bool(cache.identify(json('{"__typename": "T"}'))))
    assert_false(Bool(cache.identify(json("[1]"))))
    assert_false(Bool(cache.identify(json('{"__typename": 5, "id": 1}'))))
    assert_equal(
        cache.identify(json('{"__typename": "T", "id": [1]}')).value(), "T:[1]"
    )
    assert_equal(
        cache.identify(
            json('{"__typename": "T", "id": 1, "__ref": "R:1"}')
        ).value(),
        "R:1",
    )


def read_id_key(mut context: KeyFieldsContext) raises -> String:
    """A key function that reads `id` with `readField`."""
    var id = context.read_field("id")
    return String("K:", context.cache[].values.text(id))


def test_a_key_function_reads_with_read_field() raises:
    var config = InMemoryCacheConfig()
    var thing = TypePolicy()
    thing.key_fields = KeyFields(read_id_key)
    config.type_policies["Thing"] = thing^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "{ thing { id } }",
        '{"thing": {"__typename": "Thing", "id": "7"}}',
    )
    assert_extract(
        cache,
        (
            '{"K:7": {"__typename": "Thing", "id": "7"}, "ROOT_QUERY":'
            ' {"__typename": "Query", "thing": {"__ref": "K:7"}}}'
        ),
    )
    assert_equal(
        cache.identify(json('{"__typename": "Thing", "id": "8"}')).value(),
        "K:8",
    )


def touch_details(value: Int, mut details: ModifierDetails) raises -> Int:
    """A modifier that uses each reader of `ModifierDetails`."""
    var reference = details.to_reference("Other:1")
    assert_true(details.is_reference(reference))
    assert_true(details.can_read(reference))
    var typename = details.read_field_from("__typename", reference)
    assert_equal(String(details.cache[].values.text(typename)), "Other")
    var made = details.to_reference_object(
        json('{"__typename": "Made", "id": 3, "name": "m"}'), True
    )
    assert_equal(String(details.cache[].values.ref_text(made)), "Made:3")
    var none = details.to_reference_object(json('{"name": "n"}'), False)
    assert_equal(none, NO_VALUE)
    var plain = details.to_reference_object(json('{"__ref": "Other:1"}'), False)
    assert_true(details.is_reference(plain))
    var kept = details.to_reference_object(
        json('{"__typename": "Made", "id": 4}'), False
    )
    assert_true(details.is_reference(kept))
    return reference


def test_modifier_details_readers() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "{ link other { id } }",
        '{"link": 1, "other": {"__typename": "Other", "id": 1}}',
    )
    var fields = Dict[String, Modifier]()
    fields["link"] = touch_details
    assert_true(cache.modify(fields))
    assert_extract(
        cache,
        (
            '{"Other:1": {"__typename": "Other", "id": 1}, "ROOT_QUERY":'
            ' {"__typename": "Query", "link": {"__ref": "Other:1"}, "other":'
            ' {"__ref": "Other:1"}}, "Made:3": {"__typename": "Made", "id": 3,'
            ' "name": "m"}}'
        ),
    )


def merge_with_objects(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """A merge function that calls `mergeObjects` in each of its cases."""
    ref values = options.cache[].values
    var reference = options.to_reference("Missing:1")
    # A reference to an entity that does not exist merges nothing.
    assert_equal(options.merge_objects(incoming, reference), reference)
    var root = options.to_reference("ROOT_MUTATION")
    assert_equal(options.merge_objects(incoming, root), root)
    var other = options.to_reference("Other:1")
    assert_equal(options.merge_objects(other, other), other)
    assert_equal(options.merge_objects(incoming, NULL_VALUE), NULL_VALUE)
    var typed = values.add_reference("Typed:1")
    # Two types that differ: the incoming value wins.
    assert_equal(options.merge_objects(typed, other), other)
    var array = values.add_array(List[Int]())
    with assert_raises(contains="Cannot automatically merge arrays"):
        _ = options.merge_objects(incoming, array)
    with assert_raises(contains="Cannot automatically merge arrays"):
        _ = options.merge_objects(array, incoming)
    return options.merge_objects(existing, incoming)


def test_merge_objects_from_a_merge_function() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var box = FieldPolicy()
    box.merge = Merge(merge_with_objects)
    query_policy.fields["box"] = box^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    cache.restore(
        json(
            '{"Other:1": {"__typename": "Other", "id": 1}, "Typed:1":'
            ' {"__typename": "Typed", "id": 1}}'
        )
    )
    _ = write(cache, "{ box { a } }", '{"box": {"a": 1}}')
    _ = write(cache, "{ box { b } }", '{"box": {"b": 2}}')
    assert_extract(
        cache,
        (
            '{"Other:1": {"__typename": "Other", "id": 1}, "Typed:1":'
            ' {"__typename": "Typed", "id": 1}, "ROOT_MUTATION": {"a": 1,'
            ' "b": 2}, "ROOT_QUERY": {"__typename":'
            ' "Query", "box": {"a": 1, "b": 2}}}'
        ),
    )


def test_gc_extract_and_modify_of_entities_without_fields() raises:
    var cache = InMemoryCache()
    assert_equal(len(cache.gc()), 0)
    cache.restore(json('{"ROOT_QUERY": {}, "Empty:1": {}}'))
    assert_extract_exact(cache, '{"ROOT_QUERY":{},"Empty:1":{}}')
    assert_false(cache.modify(Dict[String, Modifier](), "Empty:1"))
    var removed = cache.gc()
    assert_equal(len(removed), 1)
    assert_equal(removed[0], "Empty:1")
    assert_equal(cache.release("Empty:1"), 0)


def test_extract_after_a_delete_and_an_add_again() raises:
    var cache = InMemoryCache()
    _ = write(cache, "{ a { id } }", '{"a": {"__typename": "A", "id": 1}}')
    _ = write(cache, "{ b { id } }", '{"b": {"__typename": "B", "id": 1}}')
    assert_true(cache.evict("A:1"))
    _ = write(cache, "{ a { id } }", '{"a": {"__typename": "A", "id": 1}}')
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__ref":"A:1"},"b":{"__ref":"B:1"}},"B:1":{"__typename":"B","id":1},"A:1":{"__typename":"A","id":1}}',
    )


def test_extract_orders_index_keys_and_index_ids() raises:
    var cache = InMemoryCache()
    cache.restore(
        json('{"x": {"b": 1, "2": 2, "1": 3}, "10": {"a": 1}, "9": {"a": 2}}')
    )
    assert_extract_exact(
        cache, '{"9":{"a":2},"10":{"a":1},"x":{"1":3,"2":2,"b":1}}'
    )


def test_restore_refuses_what_is_not_an_object() raises:
    var cache = InMemoryCache()
    with assert_raises(contains="The data to restore must be an object"):
        cache.restore(json("[]"))
    cache.restore(json('{"a": 1, "__META": {"extraRootIds": 5}}'))
    assert_extract_exact(cache, "{}")


def test_evict_and_modify_with_empty_ids() raises:
    var cache = InMemoryCache()
    assert_false(cache.evict(String("")))
    assert_false(cache.evict("Nothing:1"))
    assert_false(cache.modify(Dict[String, Modifier](), String("")))
    assert_false(cache.modify(Dict[String, Modifier](), "Nothing:1"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
