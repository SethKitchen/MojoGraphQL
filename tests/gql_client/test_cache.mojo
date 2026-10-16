# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/cache.ts`,
the `readQuery`, `readFragment`, `writeQuery` and `writeFragment` parts.

Upstream runs each `itWithInitialData` and `itWithCacheConfig` case twice,
with `resultCaching` on and off. This port has no result cache, so each
case runs once. `test_cache_2.mojo` holds the `modify` cases.

Upstream cases that are not ported:

- "prefers `from` over `id`", "can use `from` with `updateFragment`": the
  Mojo API has no `from` option. "will read some data from the store with
  `from`" and the `writeFragment` case "can use the `from` option" are
  ported with `identify`, which is what `from` does.
- "should not accidentally depend on unrelated entity fields": it tests
  the result cache.
- "should not return null when ID found in optimistic layer", the
  `recordOptimisticTransaction` case: optimistic layers are not ported.
- "does not write @stream directive as part of the cache key": `@stream`
  is not ported.
- `cache.updateQuery and cache.updateFragment`, `cache.restore` ("replaces
  cache.{store{Reader,Writer},maybeBroadcastWatch}"), `cache.batch`,
  `performTransaction`, `InMemoryCache#watch`,
  `InMemoryCache#broadcastWatches`, `resultCacheMaxSize`: they test
  watches, broadcasts, batches and internal objects, which this port does
  not have.
- `ReactiveVar and makeVar`: reactive variables are not ported.
- `TypedDocumentNode<Data, Variables>`: it tests TypeScript types.
"""

from gql_client.cache import InMemoryCache, InMemoryCacheConfig
from gql_client.policies import FieldPolicy, Merge, TypePolicy
from std.testing import TestSuite, assert_equal, assert_false, assert_raises

from _cache_helpers import object_id
from _helpers import (
    assert_extract,
    assert_extract_exact,
    assert_json,
    assert_read,
    gql,
    json,
    write,
)


def _seeded(seed: StringSlice) raises -> InMemoryCache:
    """Return a cache restored from a normalized seed."""
    var cache = InMemoryCache()
    cache.restore(json(seed))
    return cache^


def _fragment(
    mut cache: InMemoryCache,
    fragment: StringSlice,
    id: StringSlice,
    name: StringSlice = "",
    variables: StringSlice = "{}",
) raises -> String:
    """Return the `readFragment` result as JSON text, or `null`."""
    var result = cache.read_fragment(gql(fragment), id, name, json(variables))
    if not result:
        return "null"
    from gql_json.writer import stringify

    return stringify(result.value(), result.value().root)


def _assert_fragment(
    mut cache: InMemoryCache,
    fragment: StringSlice,
    id: StringSlice,
    expected: StringSlice,
    name: StringSlice = "",
    variables: StringSlice = "{}",
) raises:
    """Assert that `readFragment` gives a JSON text, in any key order."""
    var text = _fragment(cache, fragment, id, name, variables)
    if expected == "null":
        assert_equal(text, "null")
    else:
        assert_json(json(text), expected)


# --- readQuery ------------------------------------------------------------


def test_read_query_reads_some_data() raises:
    var cache = _seeded('{"ROOT_QUERY": {"a": 1, "b": 2, "c": 3}}')
    assert_read(cache, gql("{ a }"), '{"a": 1}')
    assert_read(cache, gql("{ b c }"), '{"b": 2, "c": 3}')
    assert_read(cache, gql("{ a b c }"), '{"a": 1, "b": 2, "c": 3}')


def test_read_query_reads_deeply_nested_data() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"a": 1, "b": 2, "c": 3, "d": {"__ref": "foo"}},'
        ' "foo": {"e": 4, "f": 5, "g": 6, "h": {"__ref": "bar"}}, "bar":'
        ' {"i": 7, "j": 8, "k": 9}}'
    )
    assert_read(cache, gql("{ a d { e } }"), '{"a": 1, "d": {"e": 4}}')
    assert_read(
        cache,
        gql("{ a d { e h { i } } }"),
        '{"a": 1, "d": {"e": 4, "h": {"i": 7}}}',
    )
    assert_read(
        cache,
        gql("{ a b c d { e f g h { i j k } } }"),
        (
            '{"a": 1, "b": 2, "c": 3, "d": {"e": 4, "f": 5, "g": 6, "h": {"i":'
            ' 7, "j": 8, "k": 9}}}'
        ),
    )


def test_read_query_reads_data_with_variables() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"field({\\"literal\\":true,\\"value\\":42})": 1,'
        ' "field({\\"literal\\":false,\\"value\\":42})": 2}}'
    )
    assert_read(
        cache,
        gql(
            "query ($literal: Boolean, $value: Int) { a: field(literal: true,"
            " value: 42) b: field(literal: $literal, value: $value) }"
        ),
        '{"a": 1, "b": 2}',
        '{"literal": false, "value": 42}',
    )


def test_read_query_reads_data_with_null_variables() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"field({\\"literal\\":false,\\"value\\":null})": 1}}'
    )
    assert_read(
        cache,
        gql(
            "query ($literal: Boolean, $value: Int) { a: field(literal:"
            " $literal, value: $value) }"
        ),
        '{"a": 1}',
        '{"literal": false, "value": null}',
    )


def test_read_query_does_not_mutate_its_arguments() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"field({\\"literal\\":true,\\"value\\":42})": 1,'
        ' "field({\\"literal\\":false,\\"value\\":42})": 2}}'
    )
    var text = (
        "query ($literal: Boolean, $value: Int) { a: field(literal: true,"
        " value: 42) b: field(literal: $literal, value: $value) }"
    )
    var query = gql(text)
    var variables = json('{"literal": false, "value": 42}')
    var result = cache.read_query(query, variables)
    assert_json(result.value(), '{"a": 1, "b": 2}')
    from gql_json.writer import stringify
    from gql_language.printer import print_ast

    assert_equal(
        stringify(variables, variables.root), '{"literal":false,"value":42}'
    )
    assert_equal(print_ast(query), print_ast(gql(text)))


# --- readFragment ---------------------------------------------------------


def test_read_fragment_raises_when_there_is_no_fragment() raises:
    var cache = InMemoryCache()
    with assert_raises(
        contains=(
            "Found a query operation. No operations are allowed when using a"
            " fragment as a query. Only fragments are allowed."
        )
    ):
        _ = cache.read_fragment(gql("query { a b c }"), "x")
    with assert_raises(
        contains=(
            "Found 0 fragments. `fragmentName` must be provided when there is"
            " not exactly 1 fragment."
        )
    ):
        _ = cache.read_fragment(gql("schema { query: Query }"), "x")


def test_read_fragment_raises_for_many_fragments_and_no_name() raises:
    var cache = InMemoryCache()
    with assert_raises(
        contains=(
            "Found 2 fragments. `fragmentName` must be provided when there is"
            " not exactly 1 fragment."
        )
    ):
        _ = cache.read_fragment(
            gql("fragment a on A { a } fragment b on B { b }"), "x"
        )
    with assert_raises(
        contains=(
            "Found 3 fragments. `fragmentName` must be provided when there is"
            " not exactly 1 fragment."
        )
    ):
        _ = cache.read_fragment(
            gql(
                "fragment a on A { a } fragment b on B { b } fragment c on C {"
                " c }"
            ),
            "x",
        )


def test_read_fragment_reads_nested_data_at_any_id() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"__typename": "Type1", "a": 1, "b": 2, "c": 3, "d":'
        ' {"__ref": "foo"}}, "foo": {"__typename": "Foo", "e": 4, "f": 5,'
        ' "g": 6, "h": {"__ref": "bar"}}, "bar": {"__typename": "Bar", "i": 7,'
        ' "j": 8, "k": 9}}'
    )
    _assert_fragment(
        cache,
        "fragment fragmentFoo on Foo { e h { i } }",
        "foo",
        '{"__typename": "Foo", "e": 4, "h": {"__typename": "Bar", "i": 7}}',
    )
    _assert_fragment(
        cache,
        "fragment fragmentFoo on Foo { e f g h { i j k } }",
        "foo",
        (
            '{"__typename": "Foo", "e": 4, "f": 5, "g": 6, "h": {"__typename":'
            ' "Bar", "i": 7, "j": 8, "k": 9}}'
        ),
    )
    _assert_fragment(
        cache,
        "fragment fragmentBar on Bar { i }",
        "bar",
        '{"__typename": "Bar", "i": 7}',
    )
    _assert_fragment(
        cache,
        "fragment fragmentBar on Bar { i j k }",
        "bar",
        '{"__typename": "Bar", "i": 7, "j": 8, "k": 9}',
    )
    var both = (
        "fragment fragmentFoo on Foo { e f g h { i j k } } fragment"
        " fragmentBar on Bar { i j k }"
    )
    _assert_fragment(
        cache,
        both,
        "foo",
        (
            '{"__typename": "Foo", "e": 4, "f": 5, "g": 6, "h": {"__typename":'
            ' "Bar", "i": 7, "j": 8, "k": 9}}'
        ),
        "fragmentFoo",
    )
    _assert_fragment(
        cache,
        both,
        "bar",
        '{"__typename": "Bar", "i": 7, "j": 8, "k": 9}',
        "fragmentBar",
    )


def test_read_fragment_reads_data_from_an_identified_object() raises:
    # Upstream passes `from`; `from` is `cache.identify(from)`.
    var cache = _seeded(
        '{"Foo:1": {"__typename": "Foo", "id": 1, "e": 4, "f": 5}}'
    )
    var fragment = "fragment foo on Foo { e f }"
    var expected = '{"__typename": "Foo", "e": 4, "f": 5}'
    var from_object = cache.identify(json('{"__typename": "Foo", "id": 1}'))
    _assert_fragment(cache, fragment, from_object.value(), expected)
    var from_reference = cache.identify(json('{"__ref": "Foo:1"}'))
    _assert_fragment(cache, fragment, from_reference.value(), expected)
    _assert_fragment(cache, fragment, "Foo:1", expected)


def test_read_fragment_reads_data_with_variables() raises:
    var cache = _seeded(
        '{"foo": {"__typename": "Foo",'
        ' "field({\\"literal\\":true,\\"value\\":42})": 1,'
        ' "field({\\"literal\\":false,\\"value\\":42})": 2}}'
    )
    _assert_fragment(
        cache,
        (
            "fragment foo on Foo { a: field(literal: true, value: 42) b:"
            " field(literal: $literal, value: $value) }"
        ),
        "foo",
        '{"__typename": "Foo", "a": 1, "b": 2}',
        variables='{"literal": false, "value": 42}',
    )


def test_read_fragment_returns_null_for_an_unknown_id() raises:
    var fragment = "fragment fooFragment on Foo { a b c }"
    var client1 = InMemoryCache()
    _assert_fragment(client1, fragment, "foo", "null")
    var client2 = _seeded(
        '{"bar": {"__typename": "Bar", "a": 1, "b": 2, "c": 3}}'
    )
    _assert_fragment(client2, fragment, "foo", "null")
    var client3 = _seeded(
        '{"foo": {"__typename": "Foo", "a": 1, "b": 2, "c": 3}}'
    )
    _assert_fragment(
        client3,
        fragment,
        "foo",
        '{"__typename": "Foo", "a": 1, "b": 2, "c": 3}',
    )


# --- writeQuery -----------------------------------------------------------


def test_write_query_writes_some_data() raises:
    var cache = InMemoryCache()
    _ = write(cache, "{ a }", '{"a": 1}')
    assert_extract(cache, '{"ROOT_QUERY": {"__typename": "Query", "a": 1}}')
    _ = write(cache, "{ b c }", '{"b": 2, "c": 3}')
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "a": 1, "b": 2, "c": 3}}',
    )
    _ = write(cache, "{ a b c }", '{"a": 4, "b": 5, "c": 6}')
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "a": 4, "b": 5, "c": 6}}',
    )


def test_write_query_writes_deeply_nested_data() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var d = FieldPolicy()
    d.merge = Merge(False)
    query_policy.fields["d"] = d^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(cache, "{ a d { e } }", '{"a": 1, "d": {"e": 4}}')
    assert_extract(
        cache, '{"ROOT_QUERY": {"__typename": "Query", "a": 1, "d": {"e": 4}}}'
    )
    _ = write(cache, "{ a d { h { i } } }", '{"a": 1, "d": {"h": {"i": 7}}}')
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "a": 1, "d": {"h": {"i": 7}}}}',
    )
    _ = write(
        cache,
        "{ a b c d { e f g h { i j k } } }",
        (
            '{"a": 1, "b": 2, "c": 3, "d": {"e": 4, "f": 5, "g": 6, "h": {"i":'
            ' 7, "j": 8, "k": 9}}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "a": 1, "b": 2, "c": 3,'
            ' "d": {"e": 4, "f": 5, "g": 6, "h": {"i": 7, "j": 8, "k": 9}}}}'
        ),
    )


def test_write_query_writes_data_with_variables() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        (
            "query ($literal: Boolean, $value: Int) { a: field(literal: true,"
            " value: 42) b: field(literal: $literal, value: $value) }"
        ),
        '{"a": 1, "b": 2}',
        '{"literal": false, "value": 42}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query",'
            ' "field({\\"literal\\":true,\\"value\\":42})": 1,'
            ' "field({\\"literal\\":false,\\"value\\":42})": 2}}'
        ),
    )


def test_write_query_writes_data_with_null_variables() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        (
            "query ($literal: Boolean, $value: Int) { a: field(literal: true,"
            " value: 42) b: field(literal: $literal, value: $value) }"
        ),
        '{"a": 1, "b": 2}',
        '{"literal": false, "value": null}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query",'
            ' "field({\\"literal\\":true,\\"value\\":42})": 1,'
            ' "field({\\"literal\\":false,\\"value\\":null})": 2}}'
        ),
    )


# --- writeFragment --------------------------------------------------------


def test_write_fragment_raises_when_there_is_no_fragment() raises:
    var cache = InMemoryCache()
    with assert_raises(
        contains=(
            "Found a query operation. No operations are allowed when using a"
            " fragment as a query. Only fragments are allowed."
        )
    ):
        _ = cache.write_fragment(gql("query { a b c }"), json("{}"), "x")
    with assert_raises(
        contains=(
            "Found 0 fragments. `fragmentName` must be provided when there is"
            " not exactly 1 fragment."
        )
    ):
        _ = cache.write_fragment(
            gql("schema { query: Query }"), json("{}"), "x"
        )


def test_write_fragment_raises_for_many_fragments_and_no_name() raises:
    var cache = InMemoryCache()
    with assert_raises(
        contains=(
            "Found 2 fragments. `fragmentName` must be provided when there is"
            " not exactly 1 fragment."
        )
    ):
        _ = cache.write_fragment(
            gql("fragment a on A { a } fragment b on B { b }"), json("{}"), "x"
        )
    with assert_raises(
        contains=(
            "Found 3 fragments. `fragmentName` must be provided when there is"
            " not exactly 1 fragment."
        )
    ):
        _ = cache.write_fragment(
            gql(
                "fragment a on A { a } fragment b on B { b } fragment c on C {"
                " c }"
            ),
            json("{}"),
            "x",
        )


def test_write_fragment_writes_nested_data_at_any_id() raises:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = object_id
    var cache = InMemoryCache(config)
    # The expected texts are the Node.js output of Apollo Client 4.3.3; the
    # upstream case compares them with snapshots.
    _ = cache.write_fragment(
        gql("fragment fragmentFoo on Foo { e h { i } }"),
        json('{"__typename": "Foo", "e": 4, "h": {"id": "bar", "i": 7}}'),
        "foo",
    )
    assert_extract_exact(
        cache,
        '{"bar":{"i":7},"foo":{"__typename":"Foo","e":4,"h":{"__ref":"bar"}},"__META":{"extraRootIds":["foo"]}}',
    )
    _ = cache.write_fragment(
        gql("fragment fragmentFoo on Foo { f g h { j k } }"),
        json(
            '{"__typename": "Foo", "f": 5, "g": 6, "h": {"id": "bar", "j": 8,'
            ' "k": 9}}'
        ),
        "foo",
    )
    assert_extract_exact(
        cache,
        '{"bar":{"i":7,"j":8,"k":9},"foo":{"__typename":"Foo","e":4,"h":{"__ref":"bar"},"f":5,"g":6},"__META":{"extraRootIds":["foo"]}}',
    )
    _ = cache.write_fragment(
        gql("fragment fragmentBar on Bar { i }"),
        json('{"i": 10, "__typename": "Bar"}'),
        "bar",
    )
    assert_extract_exact(
        cache,
        '{"bar":{"i":10,"j":8,"k":9,"__typename":"Bar"},"foo":{"__typename":"Foo","e":4,"h":{"__ref":"bar"},"f":5,"g":6},"__META":{"extraRootIds":["bar","foo"]}}',
    )
    _ = cache.write_fragment(
        gql("fragment fragmentBar on Bar { j k }"),
        json('{"j": 11, "k": 12, "__typename": "Bar"}'),
        "bar",
    )
    assert_extract_exact(
        cache,
        '{"bar":{"i":10,"j":11,"k":12,"__typename":"Bar"},"foo":{"__typename":"Foo","e":4,"h":{"__ref":"bar"},"f":5,"g":6},"__META":{"extraRootIds":["bar","foo"]}}',
    )
    var two = (
        "fragment fooFragment on Foo { e f g h { i j k } } fragment"
        " barFragment on Bar { i j k }"
    )
    _ = cache.write_fragment(
        gql(two),
        json(
            '{"__typename": "Foo", "e": 4, "f": 5, "g": 6, "h": {"__typename":'
            ' "Bar", "id": "bar", "i": 7, "j": 8, "k": 9}}'
        ),
        "foo",
        "fooFragment",
    )
    assert_extract_exact(
        cache,
        '{"bar":{"i":7,"j":8,"k":9,"__typename":"Bar"},"foo":{"__typename":"Foo","e":4,"h":{"__ref":"bar"},"f":5,"g":6},"__META":{"extraRootIds":["bar","foo"]}}',
    )
    _ = cache.write_fragment(
        gql(two),
        json('{"__typename": "Bar", "i": 10, "j": 11, "k": 12}'),
        "bar",
        "barFragment",
    )
    assert_extract_exact(
        cache,
        '{"bar":{"i":10,"j":11,"k":12,"__typename":"Bar"},"foo":{"__typename":"Foo","e":4,"h":{"__ref":"bar"},"f":5,"g":6},"__META":{"extraRootIds":["bar","foo"]}}',
    )


def test_write_fragment_writes_data_that_can_be_read_back() raises:
    var cache = InMemoryCache()
    var fragment = "fragment aFragment on query { getSomething { id } }"
    var data = (
        '{"__typename": "query", "getSomething": {"id": "123", "__typename":'
        ' "Something"}}'
    )
    _ = cache.write_fragment(gql(fragment), json(data), "query")
    _assert_fragment(cache, fragment, "query", data)


def test_write_fragment_writes_data_with_variables() raises:
    var cache = InMemoryCache()
    _ = cache.write_fragment(
        gql(
            "fragment foo on Foo { a: field(literal: true, value: 42) b:"
            " field(literal: $literal, value: $value) }"
        ),
        json('{"a": 1, "b": 2, "__typename": "Foo"}'),
        "foo",
        variables=json('{"literal": false, "value": 42}'),
    )
    assert_extract(
        cache,
        (
            '{"__META": {"extraRootIds": ["foo"]}, "foo": {"__typename": "Foo",'
            ' "field({\\"literal\\":true,\\"value\\":42})": 1,'
            ' "field({\\"literal\\":false,\\"value\\":42})": 2}}'
        ),
    )


def test_write_fragment_writes_to_an_identified_object() raises:
    # Upstream passes `from`; `from` is `cache.identify(from)`.
    var cache = InMemoryCache()
    var first = cache.identify(json('{"__typename": "Foo", "id": 1}'))
    _ = cache.write_fragment(
        gql("fragment foo on Foo { id a b }"),
        json('{"id": 1, "a": 1, "b": 2, "__typename": "Foo"}'),
        first.value(),
    )
    assert_extract(
        cache,
        (
            '{"__META": {"extraRootIds": ["Foo:1"]}, "Foo:1": {"__typename":'
            ' "Foo", "id": 1, "a": 1, "b": 2}}'
        ),
    )
    var second = cache.identify(json('{"__ref": "Foo:1"}'))
    _ = cache.write_fragment(
        gql("fragment foo on Foo { c d }"),
        json('{"c": 3, "d": 4, "__typename": "Foo"}'),
        second.value(),
    )
    assert_extract(
        cache,
        (
            '{"__META": {"extraRootIds": ["Foo:1"]}, "Foo:1": {"__typename":'
            ' "Foo", "id": 1, "a": 1, "b": 2, "c": 3, "d": 4}}'
        ),
    )
    _ = cache.write_fragment(
        gql("fragment foo on Foo { e f }"),
        json('{"e": 5, "f": 6, "__typename": "Foo"}'),
        "Foo:1",
    )
    assert_extract(
        cache,
        (
            '{"__META": {"extraRootIds": ["Foo:1"]}, "Foo:1": {"__typename":'
            ' "Foo", "id": 1, "a": 1, "b": 2, "c": 3, "d": 4, "e": 5, "f": 6}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
