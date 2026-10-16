# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/readFromStore.ts`.

Upstream seeds an `EntityStore` with `defaultNormalizedCacheFactory(seed)`
and reads it with `readQueryFromStore`, which is `diffQueryAgainstStore`
with `returnPartialData: false`. Here each case restores the seed with
`restore` and reads with `read_query`.

Upstream cases that are not ported:

- "uses default max size on caches", "skips iterating into an empty
  array" (the part that counts the result cache), "propagates eviction
  signals to parent queries", "only constructs MissingFieldError when
  diff.missing is accessed": they test the result cache and its sizes.
- "does not canonicalize custom scalar objects": custom scalars are not
  ported.
"""

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyArgsContext,
)
from gql_client.policies import FieldPolicy, KeyArgs, TypePolicy
from gql_client.values import Member, NO_VALUE, NULL_VALUE, UNDEFINED_VALUE
from gql_json.value import JsonDocument
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from _helpers import (
    assert_extract,
    assert_json,
    assert_read,
    gql,
    json,
    text_of,
    write,
)


def _seeded(seed: StringSlice) raises -> InMemoryCache:
    """Return a cache restored from a normalized seed."""
    var cache = InMemoryCache()
    cache.restore(json(seed))
    return cache^


def test_runs_a_nested_query_with_fragment_fields_in_arrays() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"__typename": "Query", "nestedObj": {"__ref":'
        ' "abcde"}}, "abcde": {"id": "abcde", "innerArray": [{"id": "abcdef",'
        ' "someField": 3}]}}'
    )
    assert_read(
        cache,
        gql(
            "{ ... on DummyQuery { nestedObj { innerArray { id otherField } } }"
            " ... on Query { nestedObj { innerArray { id someField } } } ... on"
            " DummyQuery { nestedObj { innerArray { id otherField2 } } } }"
        ),
        '{"nestedObj": {"innerArray": [{"id": "abcdef", "someField": 3}]}}',
    )


def test_rejects_malformed_queries() raises:
    var cache = InMemoryCache()
    with assert_raises(
        contains="Ambiguous GraphQL document: contains 2 operations"
    ):
        _ = cache.read_query(gql("query { name } query { address }"))
    with assert_raises(contains="Must contain a query definition."):
        _ = cache.read_query(gql("fragment x on y { name }"))


def test_runs_a_basic_query() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null}}'
    )
    assert_read(
        cache,
        gql("query { stringField numberField }"),
        '{"stringField": "This is a string!", "numberField": 5}',
    )


def test_runs_a_basic_query_with_arguments() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "nullField": null,'
        ' "numberField({\\"floatArg\\":3.14,\\"intArg\\":5})": 5,'
        ' "stringField({\\"arg\\":\\"This is a string!\\"})": "Heyo"}}'
    )
    assert_read(
        cache,
        gql(
            "query { id stringField(arg: $stringArg) numberField(intArg:"
            " $intArg, floatArg: $floatArg) nullField }"
        ),
        (
            '{"id": "abcd", "nullField": null, "numberField": 5, "stringField":'
            ' "Heyo"}'
        ),
        '{"intArg": 5, "floatArg": 3.14, "stringArg": "This is a string!"}',
    )


def test_runs_a_basic_query_with_custom_directives() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "firstName": "James",'
        ' "lastName@upperCase": "BOND",'
        ' "birthDate@dateFormat({\\"format\\":\\"DD-MM-YYYY\\"})":'
        ' "20-05-1940"}}'
    )
    assert_read(
        cache,
        gql(
            "query { id firstName @include(if: true) lastName @upperCase"
            ' birthDate @dateFormat(format: "DD-MM-YYYY") }'
        ),
        (
            '{"id": "abcd", "firstName": "James", "lastName": "BOND",'
            ' "birthDate": "20-05-1940"}'
        ),
    )


def test_runs_a_basic_query_with_default_values_for_arguments() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "nullField": null,'
        ' "numberField({\\"floatArg\\":3.14,\\"intArg\\":0})": 5,'
        ' "stringField({\\"arg\\":\\"This is a default string!\\"})":'
        ' "Heyo"}}'
    )
    assert_read(
        cache,
        gql(
            'query someBigQuery($stringArg: String = "This is a default'
            ' string!" $intArg: Int = 0 $floatArg: Float) { id'
            " stringField(arg: $stringArg) numberField(intArg: $intArg,"
            " floatArg: $floatArg) nullField }"
        ),
        (
            '{"id": "abcd", "nullField": null, "numberField": 5, "stringField":'
            ' "Heyo"}'
        ),
        '{"floatArg": 3.14}',
    )


def test_applies_defaults_when_variables_are_omitted() raises:
    # Upstream also passes `{ show: undefined }`, which JSON cannot hold;
    # it is the same as no variable.
    var cache = _seeded('{"ROOT_QUERY": {"__typename": "Query", "id": "abcd"}}')
    assert_read(
        cache,
        gql(
            "query someQuery($show: Boolean = false) { id field @include(if:"
            " $show) }"
        ),
        '{"id": "abcd"}',
    )


def test_runs_a_nested_query() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "nestedObj": {"__ref":'
        ' "abcde"}}, "abcde": {"id": "abcde", "stringField": "This is a'
        ' string too!", "numberField": 6, "nullField": null}}'
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField nestedObj { stringField numberField } }"
        ),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "nestedObj": {"stringField": "This is a string too!",'
            ' "numberField": 6}}'
        ),
    )


def test_runs_a_nested_query_with_multiple_fragments() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "nullObject": null,'
        ' "__typename": "Query", "nestedObj": {"__ref": "abcde"}}, "abcde":'
        ' {"id": "abcde", "stringField": "This is a string too!",'
        ' "numberField": 6, "nullField": null, "deepNestedObj": {"__ref":'
        ' "abcdef"}}, "abcdef": {"stringField": "This is a deep string",'
        ' "numberField": 7, "nullField": null}}'
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField nullField ... on Query { nestedObj {"
            " stringField nullField deepNestedObj { stringField nullField } } }"
            " ... on Query { nestedObj { numberField nullField deepNestedObj {"
            " numberField nullField } } } ... on Query { nullObject } }"
        ),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedObj": {"stringField": "This is a string'
            ' too!", "numberField": 6, "nullField": null, "deepNestedObj":'
            ' {"stringField": "This is a deep string", "numberField": 7,'
            ' "nullField": null}}, "nullObject": null}'
        ),
    )


def test_runs_a_nested_query_with_an_array_without_ids() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "nestedArray":'
        ' [{"stringField": "This is a string too!", "numberField": 6,'
        ' "nullField": null}, {"stringField": "This is a string also!",'
        ' "numberField": 7, "nullField": null}]}}'
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField nestedArray { stringField numberField }"
            " }"
        ),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "nestedArray": [{"stringField": "This is a string too!",'
            ' "numberField": 6}, {"stringField": "This is a string also!",'
            ' "numberField": 7}]}'
        ),
    )


def test_runs_a_nested_query_with_an_array_without_ids_and_a_null() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "nestedArray": [null,'
        ' {"stringField": "This is a string also!", "numberField": 7,'
        ' "nullField": null}]}}'
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField nestedArray { stringField numberField }"
            " }"
        ),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "nestedArray": [null, {"stringField": "This is a string also!",'
            ' "numberField": 7}]}'
        ),
    )


def test_runs_a_nested_query_with_an_array_with_ids_and_a_null() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "nestedArray": [null,'
        ' {"__ref": "abcde"}]}, "abcde": {"id": "abcde", "stringField": "This'
        ' is a string also!", "numberField": 7, "nullField": null}}'
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField nestedArray { id stringField"
            " numberField } }"
        ),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "nestedArray": [null, {"id": "abcde", "stringField": "This is a'
            ' string also!", "numberField": 7}]}'
        ),
    )


def test_reads_an_empty_array() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "nestedArray": [{"__ref":'
        ' "abcde"}], "emptyArray": []}, "abcde": {"id": "abcde",'
        ' "stringField": "This is a string also!", "numberField": 7,'
        ' "nullField": null}}'
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField emptyArray { id stringField numberField"
            " } }"
        ),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "emptyArray": []}'
        ),
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField nestedArray { id stringField"
            " numberField } }"
        ),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "nestedArray": [{"id": "abcde", "stringField": "This is a string'
            ' also!", "numberField": 7}]}'
        ),
    )


def test_returns_null_on_a_missing_field() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null}}'
    )
    assert_read(cache, gql("{ stringField missingField }"), "null")


def test_read_query_supports_return_partial_data() raises:
    var cache = InMemoryCache()
    _ = write(cache, "query { a }", '{"a": 123}')
    assert_read(cache, gql("query { b }"), "null")
    assert_read(cache, gql("query { a b }"), "null")
    var b = cache.read_query(gql("query { b }"), json("{}"), "ROOT_QUERY", True)
    assert_false(Bool(b))
    var ab = cache.read_query(
        gql("query { a b }"), json("{}"), "ROOT_QUERY", True
    )
    assert_json(ab.value(), '{"a": 123}')


def _fragment_text(
    mut cache: InMemoryCache,
    fragment: StringSlice,
    id: StringSlice,
    partial: Bool = False,
) raises -> String:
    """Return the `readFragment` result as JSON text, or `null`."""
    var result = cache.read_fragment(gql(fragment), id, "", json("{}"), partial)
    if not result:
        return "null"
    return text_of(result.value())


def test_read_fragment_supports_return_partial_data() raises:
    var cache = InMemoryCache()
    var id = cache.identify(json('{"__typename": "ABObject", "id": 321}'))
    assert_equal(id.value(), "ABObject:321")
    var a = "fragment AFragment on ABObject { a }"
    var b = "fragment BFragment on ABObject { b }"
    var ab = "fragment ABFragment on ABObject { a b }"
    assert_equal(_fragment_text(cache, a, id.value()), "null")
    assert_equal(_fragment_text(cache, b, id.value()), "null")
    assert_equal(_fragment_text(cache, ab, id.value()), "null")
    var written = cache.write_fragment(
        gql(a), json('{"__typename": "ABObject", "a": 123}'), id.value()
    )
    assert_equal(written, id.value())
    assert_equal(_fragment_text(cache, b, id.value()), "null")
    assert_equal(_fragment_text(cache, ab, id.value()), "null")
    assert_equal(
        _fragment_text(cache, b, id.value(), True), '{"__typename":"ABObject"}'
    )
    assert_equal(
        _fragment_text(cache, ab, id.value(), True),
        '{"__typename":"ABObject","a":123}',
    )


def read_normal(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`normal() { return { present: "here" } }`."""
    return _present(options, "here")


def read_client_only(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`clientOnly() { return { present: "also here" } }`."""
    return _present(options, "also here")


def _present(mut options: FieldFunctionOptions, text: StringSlice) -> Int:
    """Return a new object `{ present: text }`."""
    ref values = options.cache[].values
    var members = List[Member]()
    members.append(
        Member(
            Int32(values.names.intern("present")),
            Int32(values.add_string(text)),
        )
    )
    return values.add_object(members)


def test_distinguishes_missing_client_and_non_client_fields() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    query_policy.fields["normal"] = FieldPolicy(read_normal)
    query_policy.fields["clientOnly"] = FieldPolicy(read_client_only)
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    var diff = cache.diff(
        gql(
            "query { normal { present @client missing } clientOnly @client {"
            " present missing } }"
        )
    )
    assert_false(diff.complete)
    assert_json(
        diff.result.value(),
        (
            '{"normal": {"present": "here"}, "clientOnly": {"present": "also'
            ' here"}}'
        ),
    )
    var here = String(
        'Can\'t find field \'missing\' on object {\n  "present": "here"\n}'
    )
    var also = String(
        'Can\'t find field \'missing\' on object {\n  "present": "also here"\n}'
    )
    assert_equal(diff.missing.value().message, here)
    var tree = JsonDocument()
    tree.root = tree.add_object()
    var normal = tree.add_object()
    tree.add_member(normal, "missing", tree.add_string(here))
    tree.add_member(tree.root, "normal", normal)
    var client = tree.add_object()
    tree.add_member(client, "missing", tree.add_string(also))
    tree.add_member(tree.root, "clientOnly", client)
    assert_equal(text_of(diff.missing.value().missing), text_of(tree))


def test_runs_a_nested_query_where_the_reference_is_null() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "nestedObj": null}}'
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField nestedObj { stringField numberField } }"
        ),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "nestedObj": null}'
        ),
    )


def test_runs_an_array_of_non_objects() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "simpleArray": ["one", "two",'
        ' "three"]}}'
    )
    assert_read(
        cache,
        gql("{ stringField numberField simpleArray }"),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "simpleArray": ["one", "two", "three"]}'
        ),
    )


def test_runs_an_array_of_non_objects_with_null() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "simpleArray": [null, "two",'
        ' "three"]}}'
    )
    assert_read(
        cache,
        gql("{ stringField numberField simpleArray }"),
        (
            '{"stringField": "This is a string!", "numberField": 5,'
            ' "simpleArray": [null, "two", "three"]}'
        ),
    )


def test_reads_from_an_arbitrary_root_id() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"id": "abcd", "stringField": "This is a string!",'
        ' "numberField": 5, "nullField": null, "nullObject": null,'
        ' "__typename": "Query", "nestedObj": {"__ref": "abcde"}}, "abcde":'
        ' {"id": "abcde", "stringField": "This is a string too!",'
        ' "numberField": 6, "nullField": null, "deepNestedObj": {"__ref":'
        ' "abcdef"}}, "abcdef": {"stringField": "This is a deep string",'
        ' "numberField": 7, "nullField": null}}'
    )
    assert_read(
        cache,
        gql(
            "{ stringField numberField nullField deepNestedObj { stringField"
            " numberField nullField } }"
        ),
        (
            '{"stringField": "This is a string too!", "numberField": 6,'
            ' "nullField": null, "deepNestedObj": {"stringField": "This is a'
            ' deep string", "numberField": 7, "nullField": null}}'
        ),
        id="abcde",
    )
    assert_read(
        cache,
        gql("{ stringField numberField nullField }"),
        (
            '{"stringField": "This is a deep string", "numberField": 7,'
            ' "nullField": null}'
        ),
        id="abcdef",
    )


def test_handles_the_connection_directive() raises:
    var cache = _seeded('{"ROOT_QUERY": {"books:abc": [{"name": "efgh"}]}}')
    assert_read(
        cache,
        gql('{ books(skip: 0, limit: 2) @connection(key: "abc") { name } }'),
        '{"books": [{"name": "efgh"}]}',
    )


def abc_key(args: Int, mut context: KeyArgsContext) raises -> String:
    """`keyArgs: () => "abc"`."""
    return "abc"


def test_uses_a_key_args_function_in_place_of_connection() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var books = FieldPolicy()
    books.key_args = KeyArgs(abc_key)
    query_policy.fields["books"] = books^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    cache.restore(json('{"ROOT_QUERY": {"books:abc": [{"name": "efgh"}]}}'))
    assert_read(
        cache,
        gql("{ books(skip: 0, limit: 2) { name } }"),
        '{"books": [{"name": "efgh"}]}',
    )


def test_refuses_to_return_raw_reference_objects() raises:
    var cache = _seeded(
        '{"ROOT_QUERY": {"author": {"__typename": "Author", "name": "Toni'
        ' Morrison", "books": [{"title": "The Bluest Eye", "publisher":'
        ' {"__ref": "Publisher1"}}, {"title": "Song of Solomon", "publisher":'
        ' {"__ref": "Publisher2"}}, {"title": "Beloved", "publisher":'
        ' {"__ref": "Publisher2"}}]}}, "Publisher1": {"__typename":'
        ' "Publisher", "id": 1, "name": "Holt, Rinehart and Winston"},'
        ' "Publisher2": {"__typename": "Publisher", "id": 2, "name": "Alfred'
        ' A. Knopf, Inc."}}'
    )
    with assert_raises(
        contains=(
            "Missing selection set for object of type Publisher returned for"
            " query field books"
        )
    ):
        _ = cache.read_query(gql("{ author { name books } }"))
    assert_read(
        cache,
        gql("{ author { name books { title publisher { name } } } }"),
        (
            '{"author": {"__typename": "Author", "name": "Toni Morrison",'
            ' "books": [{"title": "The Bluest Eye", "publisher": {"__typename":'
            ' "Publisher", "name": "Holt, Rinehart and Winston"}}, {"title":'
            ' "Song of Solomon", "publisher": {"__typename": "Publisher",'
            ' "name": "Alfred A. Knopf, Inc."}}, {"title": "Beloved",'
            ' "publisher": {"__typename": "Publisher", "name": "Alfred A.'
            ' Knopf, Inc."}}]}}'
        ),
    )


def read_uuid(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`uuid() { return "8d573b9c-..." }`."""
    return options.cache[].values.add_string(
        "8d573b9c-cfcf-4e3e-98dd-14d255af577e"
    )


def read_null(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`null() { return null }`."""
    return NULL_VALUE


def test_read_functions_for_root_fields_work_with_an_empty_cache() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    query_policy.fields["uuid"] = FieldPolicy(read_uuid)
    query_policy.fields["null"] = FieldPolicy(read_null)
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    var expected = (
        '{"uuid": "8d573b9c-cfcf-4e3e-98dd-14d255af577e", "null": null}'
    )
    assert_read(cache, gql("query { uuid null }"), expected)
    assert_extract(cache, "{}")
    var fragment = cache.read_fragment(
        gql("fragment UUIDFragment on Query { null uuid }"), "ROOT_QUERY"
    )
    assert_json(fragment.value(), expected)
    assert_extract(cache, "{}")
    var missing = cache.read_fragment(
        gql("fragment F on Never { whatever }"), "does not exist"
    )
    assert_false(Bool(missing))
    assert_extract(cache, "{}")


def read_ducks(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`existing.map((duck) => (canRead(duck) ? duck : null))`."""
    return _map_items(options, existing, NULL_VALUE, False)


def read_chickens(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`existing.map((chicken) => (canRead(chicken) ? chicken : {}))`."""
    var empty = options.cache[].values.add_object(List[Member]())
    return _map_items(options, existing, empty, False)


def read_oxen(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`existing.filter(canRead)`."""
    return _map_items(options, existing, NO_VALUE, True)


def read_ducks_undefined(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`existing.map((duck) => (canRead(duck) ? duck : undefined))`."""
    return _map_items(options, existing, UNDEFINED_VALUE, False)


def _map_items(
    mut options: FieldFunctionOptions, existing: Int, other: Int, drop: Bool
) -> Int:
    """Keep the readable items; replace or drop the others."""
    ref values = options.cache[].values
    var items = List[Int]()
    var index = 0
    while index < values.length(existing):
        var item = values.item(existing, index)
        if options.can_read(item):
            items.append(item)
        elif not drop:
            items.append(other)
        index += 1
    return values.add_array(items)


def _diff_text(mut cache: InMemoryCache, query: StringSlice) raises -> String:
    """Return a diff as `complete result missing` text."""
    var diff = cache.diff(gql(query))
    var text = String(diff.complete) + " " + text_of(diff.result.value())
    if diff.missing:
        text += (
            " "
            + diff.missing.value().message
            + " "
            + text_of(diff.missing.value().missing)
        )
    return text^


def test_read_functions_can_map_and_filter_dangling_references() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    query_policy.fields["ducks"] = FieldPolicy(read_ducks)
    query_policy.fields["chickens"] = FieldPolicy(read_chickens)
    query_policy.fields["oxen"] = FieldPolicy(read_oxen)
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { ducks { quacking } chickens { inCoop } oxen { gee haw } }",
        (
            '{"ducks": [{"__typename": "Duck", "id": 1, "quacking": true},'
            ' {"__typename": "Duck", "id": 2, "quacking": false},'
            ' {"__typename": "Duck", "id": 3, "quacking": false}], "chickens":'
            ' [{"__typename": "Chicken", "id": 1, "inCoop": true},'
            ' {"__typename": "Chicken", "id": 2, "inCoop": true},'
            ' {"__typename": "Chicken", "id": 3, "inCoop": false}], "oxen":'
            ' [{"__typename": "Ox", "id": 1, "gee": true, "haw": false},'
            ' {"__typename": "Ox", "id": 2, "gee": false, "haw": true}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Chicken:1": {"__typename": "Chicken", "id": 1, "inCoop": true},'
            ' "Chicken:2": {"__typename": "Chicken", "id": 2, "inCoop": true},'
            ' "Chicken:3": {"__typename": "Chicken", "id": 3, "inCoop": false},'
            ' "Duck:1": {"__typename": "Duck", "id": 1, "quacking": true},'
            ' "Duck:2": {"__typename": "Duck", "id": 2, "quacking": false},'
            ' "Duck:3": {"__typename": "Duck", "id": 3, "quacking": false},'
            ' "Ox:1": {"__typename": "Ox", "id": 1, "gee": true, "haw": false},'
            ' "Ox:2": {"__typename": "Ox", "id": 2, "gee": false, "haw": true},'
            ' "ROOT_QUERY": {"__typename": "Query", "chickens": [{"__ref":'
            ' "Chicken:1"}, {"__ref": "Chicken:2"}, {"__ref": "Chicken:3"}],'
            ' "ducks": [{"__ref": "Duck:1"}, {"__ref": "Duck:2"}, {"__ref":'
            ' "Duck:3"}], "oxen": [{"__ref": "Ox:1"}, {"__ref": "Ox:2"}]}}'
        ),
    )
    var chickens = "query { chickens { id inCoop } }"
    assert_equal(
        _diff_text(cache, chickens),
        (
            'True {"chickens":[{"__typename":"Chicken","id":1,"inCoop":true},{"__typename":"Chicken","id":2,"inCoop":true},{"__typename":"Chicken","id":3,"inCoop":false}]}'
        ),
    )
    assert_true(
        cache.evict(cache.identify(json('{"__typename": "Chicken", "id": 2}')))
    )
    assert_equal(
        _diff_text(cache, chickens),
        (
            "False"
            ' {"chickens":[{"__typename":"Chicken","id":1,"inCoop":true},{},{"__typename":"Chicken","id":3,"inCoop":false}]}'
            " Can't find field 'id' on object {}"
            ' {"chickens":{"1":{"id":"Can\'t find field \'id\' on object'
            ' {}","inCoop":"Can\'t find field \'inCoop\' on object {}"}}}'
        ),
    )
    var ducks = "query { ducks { id quacking } }"
    assert_equal(
        _diff_text(cache, ducks),
        (
            'True {"ducks":[{"__typename":"Duck","id":1,"quacking":true},{"__typename":"Duck","id":2,"quacking":false},{"__typename":"Duck","id":3,"quacking":false}]}'
        ),
    )
    assert_true(
        cache.evict(cache.identify(json('{"__typename": "Duck", "id": 3}')))
    )
    assert_equal(
        _diff_text(cache, ducks),
        (
            'True {"ducks":[{"__typename":"Duck","id":1,"quacking":true},{"__typename":"Duck","id":2,"quacking":false},null]}'
        ),
    )
    var oxen = "query { oxen { id gee haw } }"
    assert_equal(
        _diff_text(cache, oxen),
        (
            'True {"oxen":[{"__typename":"Ox","id":1,"gee":true,"haw":false},{"__typename":"Ox","id":2,"gee":false,"haw":true}]}'
        ),
    )
    assert_true(
        cache.evict(cache.identify(json('{"__typename": "Ox", "id": 1}')))
    )
    assert_equal(
        _diff_text(cache, oxen),
        'True {"oxen":[{"__typename":"Ox","id":2,"gee":false,"haw":true}]}',
    )


def test_keeps_undefined_items_that_a_read_function_returns() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    query_policy.fields["ducks"] = FieldPolicy(read_ducks_undefined)
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { ducks { quacking } }",
        (
            '{"ducks": [{"__typename": "Duck", "id": 1, "quacking": true},'
            ' {"__typename": "Duck", "id": 2, "quacking": false},'
            ' {"__typename": "Duck", "id": 3, "quacking": false}]}'
        ),
    )
    var ducks = "query { ducks { id quacking } }"
    assert_equal(
        _diff_text(cache, ducks),
        (
            'True {"ducks":[{"__typename":"Duck","id":1,"quacking":true},{"__typename":"Duck","id":2,"quacking":false},{"__typename":"Duck","id":3,"quacking":false}]}'
        ),
    )
    assert_true(
        cache.evict(cache.identify(json('{"__typename": "Duck", "id": 3}')))
    )
    assert_equal(
        _diff_text(cache, ducks),
        (
            "False"
            ' {"ducks":[{"__typename":"Duck","id":1,"quacking":true},{"__typename":"Duck","id":2,"quacking":false},{}]}'
            ' Can\'t find field \'id\' on object {} {"ducks":{"2":{"id":"Can\'t'
            ' find field \'id\' on object {}","quacking":"Can\'t find field'
            " 'quacking' on object {}\"}}}"
        ),
    )


def test_missing_message_uses_json_for_embedded_parents() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "query { profile { bio } }",
        '{"profile": {"__typename": "Profile", "bio": "aaaaaaaaaa"}}',
    )
    var message = String(
        "Can't find field 'largeField' on object {\n  \"__typename\":"
        ' "Profile",\n  "bio": "aaaaaaaaaa"\n}'
    )
    var diff = cache.diff(gql("query { profile { bio largeField } }"))
    assert_false(diff.complete)
    assert_equal(
        text_of(diff.result.value()),
        '{"profile":{"__typename":"Profile","bio":"aaaaaaaaaa"}}',
    )
    assert_equal(diff.missing.value().message, message)
    var tree = JsonDocument()
    tree.root = tree.add_object()
    var profile = tree.add_object()
    tree.add_member(profile, "largeField", tree.add_string(message))
    tree.add_member(tree.root, "profile", profile)
    assert_equal(text_of(diff.missing.value().missing), text_of(tree))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
