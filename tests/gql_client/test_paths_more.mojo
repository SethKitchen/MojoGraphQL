# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""More tests of the read and write paths that the ported upstream cases
do not reach.

These cases have no upstream test file: result keys that two fields share,
the `__typename` fields that `transformDocument` adds, fragments without a
type condition, merge trees of an entity that a write meets more than
once, long error messages, and the default values of variables. Each
expected text is the output of Apollo Client 4.3.3 in Node.js.
"""

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyFieldsContext,
)
from gql_client.policies import FieldPolicy, Merge, TypePolicy
from gql_json.value import JsonDocument
from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from _helpers import (
    assert_extract_exact,
    assert_read_exact,
    gql,
    json,
    text_of,
    write,
)


def _seeded() raises -> InMemoryCache:
    """A cache with the fields that the read cases share."""
    var cache = InMemoryCache()
    cache.restore(
        json(
            '{"ROOT_QUERY": {"s": "str", "o": {"k": 1}, "l1": [{"x": 1}],'
            ' "l2": [{"y": 1}, {"y": 2}], "o1": {"x": 1}, "o2": {"z": 1}}}'
        )
    )
    return cache^


def test_result_keys_that_two_fields_share() raises:
    var cache = _seeded()
    assert_read_exact(cache, gql("{ a: s a: o { k } }"), '{"a":{"k":1}}')
    assert_read_exact(
        cache,
        gql("{ a: l1 { x } a: l2 { y } }"),
        '{"a":[{"x":1,"y":1},{"y":2}]}',
    )
    assert_read_exact(
        cache,
        gql("{ a: o1 { x } a: o2 { ... on Never { y } } }"),
        '{"a":{"x":1}}',
    )


def test_fragments_without_a_type_condition_or_a_type() raises:
    var cache = _seeded()
    assert_read_exact(
        cache, gql("{ ... { s } o { ... on T { k } } }"), '{"s":"str","o":{}}'
    )


def test_the_added_typename_fields() raises:
    var cache = InMemoryCache()
    var query = cache.transform_document(
        gql('{ a { x } b @export(as: "v") { y } c @other { d } }')
    )
    cache.restore(json('{"ROOT_QUERY": {"a": {"x": 1}, "b": {"y": 2}}}'))
    var diff = cache.diff(query)
    assert_true(not diff.complete)
    cache.restore(
        json(
            '{"ROOT_QUERY": {"a": {"x": 1}, "b": {"y": 2}, "c@other": {"d":'
            " 3}}}"
        )
    )
    var full = cache.diff(query)
    assert_true(full.complete)
    assert_equal(
        text_of(full.result.value()), '{"a":{"x":1},"b":{"y":2},"c":{"d":3}}'
    )
    cache.restore(
        json(
            '{"ROOT_QUERY": {"a": {"__typename": "A", "x": 1}, "b": {"y": 2},'
            ' "c@other": {"d": 3}}}'
        )
    )
    assert_read_exact(
        cache,
        query,
        '{"a":{"__typename":"A","x":1},"b":{"y":2},"c":{"d":3}}',
    )


def test_a_reference_in_a_nested_array_of_a_field_without_selections() raises:
    var cache = InMemoryCache()
    cache.restore(
        json(
            '{"ROOT_QUERY": {"l": [[{"__ref": "P:1"}]]}, "P:1": {"name": "p"}}'
        )
    )
    with assert_raises(
        contains=(
            "Missing selection set for object of type <undefined> returned"
            " for query field l"
        )
    ):
        _ = cache.read_query(gql("{ l }"))


def test_variables_replace_default_values() raises:
    var cache = InMemoryCache()
    var query = "query ($a: Int = 1) { f(a: $a) }"
    _ = write(cache, query, '{"f": 9}', '{"a": 2}')
    assert_extract_exact(
        cache, '{"ROOT_QUERY":{"__typename":"Query","f({\\"a\\":2})":9}}'
    )
    assert_read_exact(cache, gql(query), '{"f":9}', '{"a": 2}')


def test_a_field_twice_and_a_fragment_twice_with_merge_trees() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var z = FieldPolicy()
    z.merge = Merge(False)
    query_policy.fields["z"] = z^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        (
            "{ a { y } ... on Query { a { w } } ... { b } ...F ...F } fragment"
            " F on Query { c }"
        ),
        '{"a": {"y": 1, "w": 2}, "b": 3, "c": 4}',
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"y":1,"w":2},"b":3,"c":4}}',
    )


def concat_books(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`merge(e = [], i) { return [...e, ...i] }`."""
    ref values = options.cache[].values
    var items = values.array_items(existing)
    items.extend(Span(values.array_items(incoming)))
    return values.add_array(items)


def _author_cache() raises -> InMemoryCache:
    """A cache whose `Author.books` concatenates."""
    var config = InMemoryCacheConfig()
    var author = TypePolicy()
    var books = FieldPolicy()
    books.merge = Merge(concat_books)
    author.fields["books"] = books^
    config.type_policies["Author"] = author^
    return InMemoryCache(config)


def test_merge_trees_of_an_entity_met_more_than_once() raises:
    var cache = _author_cache()
    _ = write(
        cache,
        (
            "{ first: author(n: 1) { id books } second: author(n: 2) { id books"
            " } third: author(n: 3) { id } fourth: author(n: 4) { id books } }"
        ),
        (
            '{"first": {"__typename": "Author", "id": 1, "books": ["a"]},'
            ' "second": {"__typename": "Author", "id": 1, "books": ["b"]},'
            ' "third": {"__typename": "Author", "id": 1}, "fourth":'
            ' {"__typename": "Author", "id": 1, "books": ["c"]}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Author:1":{"__typename":"Author","id":1,"books":["c"]},"ROOT_QUERY":{"__typename":"Query","author({\\"n\\":1})":{"__ref":"Author:1"},"author({\\"n\\":2})":{"__ref":"Author:1"},"author({\\"n\\":3})":{"__ref":"Author:1"},"author({\\"n\\":4})":{"__ref":"Author:1"}}}',
    )
    var other = _author_cache()
    _ = write(
        other,
        "{ third: author(n: 3) { id } first: author(n: 1) { id books } }",
        (
            '{"third": {"__typename": "Author", "id": 1}, "first":'
            ' {"__typename": "Author", "id": 1, "books": ["a"]}}'
        ),
    )
    assert_extract_exact(
        other,
        '{"Author:1":{"__typename":"Author","id":1,"books":["a"]},"ROOT_QUERY":{"__typename":"Query","author({\\"n\\":3})":{"__ref":"Author:1"},"author({\\"n\\":1})":{"__ref":"Author:1"}}}',
    )


def test_a_long_object_in_an_error_message_is_cut() raises:
    var cache = InMemoryCache()
    var long_text = String("x") * 1100
    var data = JsonDocument()
    data.root = data.add_object()
    data.add_member(data.root, "s", data.add_string(long_text))
    var shown = String('{\n  "s": "') + long_text
    var expected = "Could not identify object " + String(shown[byte=:1000])
    try:
        _ = cache.write_fragment(gql("fragment F on T { s }"), data)
        assert_true(False)
    except e:
        assert_equal(String(e), expected)


def no_id(mut context: KeyFieldsContext) raises -> String:
    """`dataIdFromObject: () => undefined`."""
    return ""


def test_a_custom_id_function_with_an_empty_result() raises:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = no_id
    var cache = InMemoryCache(config)
    _ = cache.write_fragment(
        gql("fragment F on T { a }"), JsonDocument(), "X:1"
    )
    assert_extract_exact(cache, '{"X:1":{},"__META":{"extraRootIds":["X:1"]}}')
    _ = write(cache, "{ a { b } }", '{"a": 5}')
    assert_extract_exact(
        cache,
        '{"X:1":{},"ROOT_QUERY":{"__typename":"Query","a":{}},"__META":{"extraRootIds":["X:1"]}}',
    )


def test_a_connection_key_that_is_not_a_string() raises:
    # Upstream fails here with a TypeError: `storeFieldName.match` of a
    # number. The port writes the key as JSON text.
    var cache = InMemoryCache()
    _ = write(cache, "{ i(s: 1) @connection(key: 5, filter: [1]) }", '{"i": 4}')
    assert_extract_exact(cache, '{"ROOT_QUERY":{"__typename":"Query","i:5":4}}')


def test_a_forbidden_alias_in_a_fragment_document() raises:
    var cache = InMemoryCache()
    with assert_raises(
        contains=(
            "`__typename` is a forbidden field alias name in the selection"
            ' set for field `name` in query "(anonymous)".'
        )
    ):
        _ = cache.diff(gql("fragment F on T { __typename: name }"))


def _three_merges() raises -> InMemoryCache:
    """A cache whose `Author.books`, `tags` and `pets` concatenate."""
    var config = InMemoryCacheConfig()
    var author = TypePolicy()
    var names: List[String] = ["books", "tags", "pets"]
    for ref name in names:
        var field = FieldPolicy()
        field.merge = Merge(concat_books)
        author.fields[name] = field^
    config.type_policies["Author"] = author^
    return InMemoryCache(config)


def test_merge_trees_with_keys_on_one_side_only() raises:
    var cache = _three_merges()
    _ = write(
        cache,
        (
            "{ x: author(n: 1) { id books tags } y: author(n: 2) { id pets"
            " tags } }"
        ),
        (
            '{"x": {"__typename": "Author", "id": 1, "books": ["b"], "tags":'
            ' ["t1"]}, "y": {"__typename": "Author", "id": 1, "pets": ["p"],'
            ' "tags": ["t2"]}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Author:1":{"__typename":"Author","id":1,"books":["b"],"tags":["t2"],"pets":["p"]},"ROOT_QUERY":{"__typename":"Query","author({\\"n\\":1})":{"__ref":"Author:1"},"author({\\"n\\":2})":{"__ref":"Author:1"}}}',
    )


def test_a_field_with_a_merge_option_twice() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var a = FieldPolicy()
    a.merge = Merge(True)
    query_policy.fields["a"] = a^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(
        cache, "{ a { y } ... on Query { a { w } } }", '{"a": {"y": 1, "w": 2}}'
    )
    assert_extract_exact(
        cache, '{"ROOT_QUERY":{"__typename":"Query","a":{"y":1,"w":2}}}'
    )


def test_a_fragment_inside_a_fuzzy_fragment() raises:
    var config = InMemoryCacheConfig()
    var subtypes: List[String] = ["X.*"]
    config.possible_types["S"] = subtypes^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "{ a { ... on S { b ... on Q { c } } } }",
        '{"a": {"__typename": "Xa", "b": 1, "c": 2}}',
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","a":{"__typename":"Xa","b":1}}}',
    )


def test_a_reference_inside_an_object_of_a_list_without_selections() raises:
    var cache = InMemoryCache()
    cache.restore(
        json(
            '{"ROOT_QUERY": {"l": [{"a": [{"__ref": "P:1"}]}]}, "P:1":'
            ' {"__typename": "P"}}'
        )
    )
    with assert_raises(
        contains=(
            "Missing selection set for object of type P returned for query"
            " field l"
        )
    ):
        _ = cache.read_query(gql("{ l }"))


def test_a_cut_message_ends_on_a_whole_character() raises:
    var cache = InMemoryCache()
    # 991 bytes come before the first "é": "{", a line break, two
    # spaces, "\"s\": \"" (10 bytes) and 981 "x". Each "é" is two bytes,
    # so byte 1000 is in the middle of one.
    var text = String("x") * 981 + String("é") * 20
    var data = JsonDocument()
    data.root = data.add_object()
    data.add_member(data.root, "s", data.add_string(text))
    try:
        _ = cache.write_fragment(gql("fragment F on T { s }"), data)
        assert_true(False)
    except e:
        var message = String(e)
        assert_true(message.endswith("é"))
        assert_equal(
            message.byte_length(),
            String("Could not identify object ").byte_length() + 999,
        )


def typed_objects(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """A merge function that merges a typed object with an untyped one."""
    ref values = options.cache[].values
    var typed = values.from_json(json('{"__typename": "T", "k": 1}'), 0)
    var merged = options.merge_objects(typed, incoming)
    assert_equal(values.stringify(merged), '{"__typename":"T","k":1,"a":1}')
    return incoming


def test_merge_objects_of_a_typed_and_an_untyped_object() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var box = FieldPolicy()
    box.merge = Merge(typed_objects)
    query_policy.fields["box"] = box^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(cache, "{ box { a } }", '{"box": {"a": 1}}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
