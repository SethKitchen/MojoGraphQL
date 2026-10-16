# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3
`src/cache/inmemory/__tests__/diffAgainstStore.ts`.

Upstream writes with a `StoreWriter`, or seeds a store, and diffs with
`StoreReader.diffQueryAgainstStore`, whose `returnPartialData` is true by
default. Here each case writes with `write_query` or restores a seed, and
diffs with `diff`, which has the same default.

Upstream checks that are not ported:

- "referential equality preservation": the `previousResult` option and
  the `toBe` / `not.toBe` identity checks. Upstream ignores
  `previousResult` since 3.0, and a Mojo diff builds a new result, so the
  cases here check the result values only.
- "should not return results containing cycles": JSON data cannot hold a
  cycle, so the case writes the acyclic part of the result that the query
  selects.
- The console checks of `withError`: the cache prints no warnings.
"""

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyFieldsContext,
)
from gql_client.policies import FieldPolicy, KeyFields, TypePolicy
from gql_client.read import DiffResult
from gql_client.values import NO_VALUE, ValueKind
from gql_json.value import JsonDocument
from gql_json.writer import stringify
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from _helpers import assert_extract, assert_json, canonical, gql, json, write


def _diff(
    mut cache: InMemoryCache, query: StringSlice, partial: Bool = True
) raises -> DiffResult:
    """Diff a query against a cache."""
    return cache.diff(gql(query), json("{}"), "ROOT_QUERY", partial)


def _result(diff: DiffResult) -> String:
    """Return the result of a diff as JSON text, or `null`."""
    if not diff.result:
        return "null"
    ref document = diff.result.value()
    return stringify(document, document.root)


def _missing_tree(message: String, path: List[String]) -> String:
    """Return the JSON text of a missing tree with one message at a path."""
    var document = JsonDocument()
    var node = document.add_string(message)
    var index = len(path) - 1
    while index >= 0:
        var object = document.add_object()
        document.add_member(object, path[index], node)
        node = object
        index -= 1
    return stringify(document, node)


def test_named_fragments_are_incomplete_against_an_empty_store() raises:
    var cache = InMemoryCache()
    var diff = _diff(
        cache,
        (
            "query foo { ...root } fragment root on Query { nestedObj {"
            " innerArray { id someField } } }"
        ),
    )
    assert_false(diff.complete)
    assert_equal(_result(diff), "null")


def test_inline_fragments_are_incomplete_against_an_empty_store() raises:
    var cache = InMemoryCache()
    var diff = _diff(
        cache,
        (
            "{ ... on DummyQuery { nestedObj { innerArray { id otherField } } }"
            " ... on Query { nestedObj { innerArray { id someField } } } ... on"
            " DummyQuery2 { nestedObj { innerArray { id otherField2 } } } }"
        ),
    )
    assert_false(diff.complete)
    assert_equal(_result(diff), "null")


def test_returns_nothing_when_the_store_is_enough() raises:
    var cache = InMemoryCache()
    var query = '{ people_one(id: "1") { name } }'
    var result = '{"people_one": {"name": "Luke Skywalker"}}'
    _ = write(cache, query, result)
    var diff = _diff(cache, query)
    assert_true(diff.complete)
    assert_equal(canonical(_result(diff)), canonical(result))


def test_complete_empty_result_when_every_field_is_skipped() raises:
    var cache = InMemoryCache()
    var query = (
        "query { firstName @include(if: false) lastName @skip(if: true) }"
    )
    _ = write(cache, query, "{}")
    var diff = _diff(cache, query)
    assert_true(diff.complete)
    assert_equal(_result(diff), "{}")
    assert_false(Bool(diff.missing))


def test_caches_root_queries_under_the_id_of_the_node() raises:
    var config = InMemoryCacheConfig()
    var person = TypePolicy()
    person.key_fields = KeyFields.parse('["id"]')
    config.type_policies["Person"] = person^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        '{ people_one(id: "1") { __typename idAlias: id name } }',
        (
            '{"people_one": {"__typename": "Person", "idAlias": "1", "name":'
            ' "Luke Skywalker"}}'
        ),
    )
    var diff = _diff(cache, '{ people_one(id: "1") { __typename id name } }')
    assert_true(diff.complete)
    assert_equal(
        canonical(_result(diff)),
        canonical(
            '{"people_one": {"__typename": "Person", "id": "1", "name": "Luke'
            ' Skywalker"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Person:{\\"id\\":\\"1\\"}": {"__typename": "Person", "id": "1",'
            ' "name": "Luke Skywalker"}, "ROOT_QUERY": {"__typename": "Query",'
            ' "people_one({\\"id\\":\\"1\\"})": {"__ref":'
            ' "Person:{\\"id\\":\\"1\\"}"}}}'
        ),
    )


def test_does_not_swallow_errors_other_than_field_errors() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "query { person { powers } }",
        '{"person": {"powers": "the force"}}',
    )
    with assert_raises(contains="No fragment named notARealFragment"):
        _ = _diff(cache, "query { ...notARealFragment }")


def test_does_not_error_on_a_correct_query_with_union_fragments() raises:
    var cache = InMemoryCache()
    var first = (
        '{"person": {"__typename": "Author", "firstName": "John", "lastName":'
        ' "Smith"}}'
    )
    _ = write(
        cache, "query { person { __typename firstName lastName } }", first
    )
    var diff = _diff(
        cache,
        (
            "query { person { __typename ... on Author { firstName lastName }"
            " ... on Jedi { powers } } }"
        ),
        False,
    )
    assert_true(diff.complete)
    assert_equal(canonical(_result(diff)), canonical(first))


def test_fields_missing_from_all_but_one_named_fragment() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "query { person { __typename firstName lastName } }",
        (
            '{"person": {"__typename": "Author", "firstName": "John",'
            ' "lastName": "Smith"}}'
        ),
    )
    var diff = _diff(
        cache,
        (
            "query { person { __typename ...authorInfo ...jediInfo } } fragment"
            " authorInfo on Author { firstName } fragment jediInfo on Jedi {"
            " powers }"
        ),
    )
    assert_true(diff.complete)
    assert_equal(
        canonical(_result(diff)),
        canonical('{"person": {"__typename": "Author", "firstName": "John"}}'),
    )


def test_null_result_when_matching_named_fragments_miss_fields() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "query { person { __typename firstName lastName } }",
        (
            '{"person": {"__typename": "Author", "firstName": "John",'
            ' "lastName": "Smith"}}'
        ),
    )
    var diff = _diff(
        cache,
        (
            "query { person { __typename ...authorInfo2 ...jediInfo2 } }"
            " fragment authorInfo2 on Author { firstName address } fragment"
            " jediInfo2 on Jedi { jedi }"
        ),
        False,
    )
    var message = String(
        "Can't find field 'address' on object {\n  \"__typename\":"
        ' "Author",\n  "firstName": "John",\n  "lastName": "Smith"\n}'
    )
    assert_false(diff.complete)
    assert_equal(_result(diff), "null")
    assert_equal(diff.missing.value().message, message)
    var path: List[String] = ["person", "address"]
    ref tree = diff.missing.value().missing
    assert_equal(stringify(tree, tree.root), _missing_tree(message, path))


def test_returns_available_fields_with_return_partial_data() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        '{ people_one(id: "1") { __typename id name } }',
        (
            '{"people_one": {"__typename": "Person", "id": "lukeId", "name":'
            ' "Luke Skywalker"}}'
        ),
    )
    var expected = canonical(
        '{"people_one": {"__typename": "Person", "name": "Luke Skywalker"}}'
    )
    var simple = '{ people_one(id: "1") { name age } }'
    var queries: List[String] = [
        simple,
        '{ people_one(id: "1") { ... on Person { name age } } }',
        (
            'query { people_one(id: "1") { ...personInfo } } fragment'
            " personInfo on Person { name age }"
        ),
    ]
    for ref query in queries:
        var diff = _diff(cache, query)
        assert_false(diff.complete)
        assert_equal(canonical(_result(diff)), expected)
    var diff = _diff(cache, simple, False)
    var message = String("Can't find field 'age' on Person:lukeId object")
    assert_false(diff.complete)
    assert_equal(_result(diff), "null")
    assert_equal(diff.missing.value().message, message)
    var path: List[String] = ["people_one", "age"]
    ref tree = diff.missing.value().missing
    assert_equal(stringify(tree, tree.root), _missing_tree(message, path))


def object_id(mut context: KeyFieldsContext) raises -> String:
    """`dataIdFromObject(obj) { return obj.id }`."""
    var id = context.field("id")
    ref values = context.cache[].values
    var kind = values.kind(id)
    if kind == ValueKind.STRING or kind == ValueKind.NUMBER:
        return String(values.text(id))
    return ""


def test_will_add_a_private_id_property() raises:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = object_id
    var cache = InMemoryCache(config)
    var query = "query { a { id b } c { d e { id f } g { h } } }"
    var result = (
        '{"a": [{"id": "a:1", "b": 1.1}, {"id": "a:2", "b": 1.2}, {"id":'
        ' "a:3", "b": 1.3}], "c": {"d": 2, "e": [{"id": "e:1", "f": 3.1},'
        ' {"id": "e:2", "f": 3.2}, {"id": "e:3", "f": 3.3}, {"id": "e:4", "f":'
        ' 3.4}, {"id": "e:5", "f": 3.5}], "g": {"h": 4}}}'
    )
    _ = write(cache, query, result)
    var diff = _diff(cache, query)
    assert_equal(canonical(_result(diff)), canonical(result))
    ref document = diff.result.value()
    var a = document.get(document.root, "a")
    var e = document.get(document.get(document.root, "c"), "e")
    var ids: List[String] = ["a:1", "a:2", "a:3"]
    for index in range(len(ids)):
        var item = json(stringify(document, document.at(a, index)))
        assert_equal(cache.identify(item).value(), ids[index])
    var e_ids: List[String] = ["e:1", "e:2", "e:3", "e:4", "e:5"]
    for index in range(len(e_ids)):
        var item = json(stringify(document, document.at(e, index)))
        assert_equal(cache.identify(item).value(), e_ids[index])


def _check_value_roundtrip(query: StringSlice, result: StringSlice) raises:
    """Write a result with the default cache and diff it back."""
    var cache = InMemoryCache()
    _ = write(cache, query, result)
    var diff = _diff(cache, query)
    assert_true(diff.complete)
    assert_equal(canonical(_result(diff)), canonical(result))


def test_returns_the_written_result_when_nothing_changed() raises:
    _check_value_roundtrip(
        "query { a { b } c { d e { f } } }",
        '{"a": {"b": 1}, "c": {"d": 2, "e": {"f": 3}}}',
    )


def test_returns_the_written_result_with_child_arrays() raises:
    _check_value_roundtrip(
        "query { a { b } c { d e { f } } }",
        (
            '{"a": [{"b": 1.1}, {"b": 1.2}, {"b": 1.3}], "c": {"d": 2, "e":'
            ' [{"f": 3.1}, {"f": 3.2}, {"f": 3.3}, {"f": 3.4}, {"f": 3.5}]}}'
        ),
    )


def test_does_not_add_zombie_items() raises:
    _check_value_roundtrip(
        "query { a { b } }", '{"a": [{"b": 1.1}, {"b": 1.2}]}'
    )


def test_returns_the_written_result_with_nested_child_arrays() raises:
    _check_value_roundtrip(
        "query { a { b } c { d e { f } } }",
        (
            '{"a": [[[[[{"b": 1.1}, {"b": 1.2}, {"b": 1.3}]]]]], "c": {"d": 2,'
            ' "e": [[{"f": 3.1}, {"f": 3.2}, {"f": 3.3}], [{"f": 3.4}, {"f":'
            " 3.5}]]}}"
        ),
    )


def test_returns_items_with_ids_in_their_written_order() raises:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = object_id
    var cache = InMemoryCache(config)
    var query = "query { a { id b } c { d e { id f } g { h } } }"
    var result = (
        '{"a": [{"id": "a:1", "b": 1.1}, {"id": "a:2", "b": 1.2}, {"id":'
        ' "a:3", "b": 1.3}], "c": {"d": 2, "e": [{"id": "e:1", "f": 3.1},'
        ' {"id": "e:2", "f": 3.2}, {"id": "e:3", "f": 3.3}, {"id": "e:4", "f":'
        ' 3.4}, {"id": "e:5", "f": 3.5}], "g": {"h": 4}}}'
    )
    _ = write(cache, query, result)
    assert_equal(canonical(_result(_diff(cache, query))), canonical(result))


def test_returns_the_same_json_scalar_field_object() raises:
    _check_value_roundtrip(
        "{ a { b c } d { e f } }",
        (
            '{"a": {"b": 1, "c": {"x": 2, "y": 3, "z": 4}}, "d": {"e": 5, "f":'
            ' {"x": 6, "y": 7, "z": 8}}}'
        ),
    )


def read_person(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """The `person` read function of "will preserve equality with custom
    resolvers": find the person of `args.id` in `people`."""
    ref values = options.cache[].values
    var id = values.get(options.args, "id")
    assert_equal(values.kind(id), ValueKind.NUMBER)
    var object = json(
        String('{"__typename": "Person", "id": ', values.text(id), "}")
    )
    var reference = options.cache[].to_reference_object(object, False)
    assert_true(options.is_reference(reference))
    var expected = String('Person:{"id":', values.text(id), "}")
    assert_equal(String(values.ref_text(reference)), expected)
    var people = options.read_field("people")
    var index = 0
    while index < values.length(people):
        var person = values.item(people, index)
        if String(values.ref_text(person)) == expected:
            return person
        index += 1
    return NO_VALUE


def test_preserves_equality_with_custom_resolvers() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    query_policy.fields["person"] = FieldPolicy(read_person)
    config.type_policies["Query"] = query_policy^
    var person = TypePolicy()
    person.key_fields = KeyFields.parse('["id"]')
    config.type_policies["Person"] = person^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "{ people { id name __typename } }",
        (
            '{"people": [{"id": 4, "name": "Luke Skywalker", "__typename":'
            ' "Person"}]}'
        ),
    )
    var diff = _diff(cache, "{ person(id: 4) { id name __typename } }")
    assert_equal(
        canonical(_result(diff)),
        canonical(
            '{"person": {"id": 4, "name": "Luke Skywalker", "__typename":'
            ' "Person"}}'
        ),
    )


def test_throws_for_object_fields_without_selection_sets() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "query getMessageList { messageList { id __typename message } }",
        (
            '{"messageList": [{"id": 1, "__typename": "Message", "message":'
            ' "hi"}, {"id": 2, "__typename": "Message", "message": "hello"},'
            ' {"id": 3, "__typename": "Message", "message": "hey"}]}'
        ),
    )
    with assert_raises(
        contains=(
            "Missing selection set for object of type Message returned for"
            " query field messageList"
        )
    ):
        _ = _diff(cache, "query getMessageList { messageList }")


def test_does_not_return_results_containing_cycles() raises:
    var query = (
        "query Query { user { ...UserFragment company { users {"
        " ...UserFragment } } } } fragment UserFragment on User { id name"
        " company { id name } }"
    )
    var company = '{"__typename": "Company", "id": 1, "name": "Apollo"}'
    var data = String(
        (
            '{"user": {"__typename": "User", "id": 1, "name": "Ben", "company":'
            ' {"__typename": "Company", "id": 1, "name": "Apollo", "users":'
            ' [{"__typename": "User", "id": 1, "name": "Ben", "company": '
        ),
        company,
        '}, {"__typename": "User", "id": 2, "name": "James", "company": ',
        company,
        "}]}}}",
    )
    var expected = canonical(
        '{"user": {"__typename": "User", "id": 1, "name": "Ben", "company":'
        ' {"__typename": "Company", "id": 1, "name": "Apollo", "users":'
        ' [{"__typename": "User", "id": 1, "name": "Ben", "company":'
        ' {"__typename": "Company", "id": 1, "name": "Apollo"}},'
        ' {"__typename": "User", "id": 2, "name": "James", "company":'
        ' {"__typename": "Company", "id": 1, "name": "Apollo"}}]}}}'
    )
    # Upstream checks with `dataIdFromObject: void 0` and with
    # `defaultDataIdFromObject`; both are the default id function.
    for _ in range(2):
        var cache = InMemoryCache()
        _ = write(cache, query, data)
        var text = _result(_diff(cache, query))
        assert_true('"Ben"' in text)
        assert_true('"James"' in text)
        assert_equal(canonical(text), expected)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
