# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/writeToStore.ts`.

Upstream writes with a `StoreWriter` and compares `store.toObject()`. Here
each case writes with `write_query` and compares `extract()`, which is
`toObject()` when no id other than a root is retained.

Upstream cases that are not ported:

- "Cache data may be lost..." warnings, "should warn when it receives the
  wrong data inside a fragment", "should warn if a result is missing
  __typename", "should not warn if a field is null / deferred": the cache
  prints no development warnings. "should write the result data without
  validating its shape", the non-union fragment case and "should not warn
  when scalar fields are updated" are ported for their store contents
  only, and "should warn if it cannot identify the result object" for its
  error.
- "should skip writing still-fresh result objects", "does not change
  object references if the value is the same", "should not deep-freeze
  scalar objects": they test object identity and the result cache, which
  a Mojo cache does not have.
- "should allow silencing broadcast of cache updates": there are no
  watches.
- "StoreWriter flattenFields ..." (four cases): they test the internal
  `@client` and `@defer` contexts, which this port does not keep.
- "@stream": `@stream` merging is not ported.
"""

from std.collections import Dict

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyArgsContext,
    KeyFieldsContext,
)
from gql_client.helpers import store_key_name_from_field
from gql_client.policies import (
    FieldPolicy,
    KeyArgs,
    KeyFields,
    Merge,
    TypePolicy,
)
from gql_client.values import NO_VALUE, UNDEFINED_VALUE, ValueKind, Values
from gql_language.ast import Role
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
    assert_read,
    assert_read_exact,
    gql,
    json,
    write,
)
from _policies import get_id_field, typename_id


def _typename_cache() raises -> InMemoryCache:
    """The test-level cache of upstream: `__typename__id` ids."""
    var config = InMemoryCacheConfig()
    config.data_id_from_object = typename_id
    return InMemoryCache(config)


def _id_cache() raises -> InMemoryCache:
    """A cache with `dataIdFromObject: getIdField`."""
    var config = InMemoryCacheConfig()
    config.data_id_from_object = get_id_field
    return InMemoryCache(config)


def test_normalizes_a_trivial_item() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        "{ id stringField numberField nullField }",
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null}}'
        ),
    )


def test_normalizes_an_aliased_field() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        "{ id aliasedField: stringField numberField nullField }",
        (
            '{"id": "abcd", "aliasedField": "This is a string!", "numberField":'
            ' 5, "nullField": null}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null}}'
        ),
    )


def test_normalizes_aliased_fields_with_arguments() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        (
            "{ id aliasedField1: stringField(arg: 1) aliasedField2:"
            " stringField(arg: 2) numberField nullField }"
        ),
        (
            '{"id": "abcd", "aliasedField1": "The arg was 1!", "aliasedField2":'
            ' "The arg was 2!", "numberField": 5, "nullField": null}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField({\\"arg\\":1})": "The arg was 1!",'
            ' "stringField({\\"arg\\":2})": "The arg was 2!", "numberField": 5,'
            ' "nullField": null}}'
        ),
    )


def test_normalizes_a_query_with_variables() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        (
            "{ id stringField(arg: $stringArg) numberField(intArg: $intArg,"
            " floatArg: $floatArg) nullField }"
        ),
        (
            '{"id": "abcd", "stringField": "Heyo", "numberField": 5,'
            ' "nullField": null}'
        ),
        '{"intArg": 5, "floatArg": 3.14, "stringArg": "This is a string!"}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd", "nullField":'
            ' null, "numberField({\\"floatArg\\":3.14,\\"intArg\\":5})": 5,'
            ' "stringField({\\"arg\\":\\"This is a string!\\"})": "Heyo"}}'
        ),
    )


def test_normalizes_a_query_with_default_values() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        (
            'query someBigQuery($stringArg: String = "This is a default'
            ' string!" $intArg: Int $floatArg: Float) { id stringField(arg:'
            " $stringArg) numberField(intArg: $intArg, floatArg: $floatArg)"
            " nullField }"
        ),
        (
            '{"id": "abcd", "stringField": "Heyo", "numberField": 5,'
            ' "nullField": null}'
        ),
        '{"intArg": 5, "floatArg": 3.14}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd", "nullField":'
            ' null, "numberField({\\"floatArg\\":3.14,\\"intArg\\":5})": 5,'
            ' "stringField({\\"arg\\":\\"This is a default string!\\"})":'
            ' "Heyo"}}'
        ),
    )


def test_normalizes_a_query_with_custom_directives() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        (
            "query { id firstName @include(if: true) lastName @upperCase"
            ' birthDate @dateFormat(format: "DD-MM-YYYY") }'
        ),
        (
            '{"id": "abcd", "firstName": "James", "lastName": "BOND",'
            ' "birthDate": "20-05-1940"}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd", "firstName":'
            ' "James", "lastName@upperCase": "BOND",'
            ' "birthDate@dateFormat({\\"format\\":\\"DD-MM-YYYY\\"})":'
            ' "20-05-1940"}}'
        ),
    )


def test_normalizes_a_nested_object_with_an_id() raises:
    var cache = _id_cache()
    _ = write(
        cache,
        (
            "{ id stringField numberField nullField nestedObj { id stringField"
            " numberField nullField } }"
        ),
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "nestedObj": {"id": "abcde", "stringField":'
            ' "This is a string too!", "numberField": 6, "nullField": null}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedObj": {"__ref": "abcde"}}, "abcde":'
            ' {"id": "abcde", "stringField": "This is a string too!",'
            ' "numberField": 6, "nullField": null}}'
        ),
    )


def test_normalizes_a_nested_object_without_an_id() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        (
            "{ id stringField numberField nullField nestedObj { stringField"
            " numberField nullField } }"
        ),
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "nestedObj": {"stringField": "This is a'
            ' string too!", "numberField": 6, "nullField": null}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedObj": {"stringField": "This is a string'
            ' too!", "numberField": 6, "nullField": null}}}'
        ),
    )


def test_normalizes_a_nested_object_with_arguments_without_an_id() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        (
            '{ id stringField numberField nullField nestedObj(arg: "val") {'
            " stringField numberField nullField } }"
        ),
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "nestedObj": {"stringField": "This is a'
            ' string too!", "numberField": 6, "nullField": null}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedObj({\\"arg\\":\\"val\\"})":'
            ' {"stringField": "This is a string too!", "numberField": 6,'
            ' "nullField": null}}}'
        ),
    )


def test_normalizes_a_nested_array_with_ids() raises:
    var cache = _id_cache()
    _ = write(
        cache,
        (
            "{ id stringField numberField nullField nestedArray { id"
            " stringField numberField nullField } }"
        ),
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "nestedArray": [{"id": "abcde",'
            ' "stringField": "This is a string too!", "numberField": 6,'
            ' "nullField": null}, {"id": "abcdef", "stringField": "This is a'
            ' string also!", "numberField": 7, "nullField": null}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedArray": [{"__ref": "abcde"}, {"__ref":'
            ' "abcdef"}]}, "abcde": {"id": "abcde", "stringField": "This is a'
            ' string too!", "numberField": 6, "nullField": null}, "abcdef":'
            ' {"id": "abcdef", "stringField": "This is a string also!",'
            ' "numberField": 7, "nullField": null}}'
        ),
    )


def test_normalizes_a_nested_array_with_ids_and_a_null() raises:
    var cache = _id_cache()
    _ = write(
        cache,
        (
            "{ id stringField numberField nullField nestedArray { id"
            " stringField numberField nullField } }"
        ),
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "nestedArray": [{"id": "abcde",'
            ' "stringField": "This is a string too!", "numberField": 6,'
            ' "nullField": null}, null]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedArray": [{"__ref": "abcde"}, null]},'
            ' "abcde": {"id": "abcde", "stringField": "This is a string too!",'
            ' "numberField": 6, "nullField": null}}'
        ),
    )


def test_normalizes_a_nested_array_without_ids() raises:
    var cache = _typename_cache()
    var data = (
        '{"id": "abcd", "stringField": "This is a string!", "numberField": 5,'
        ' "nullField": null, "nestedArray": [{"stringField": "This is a'
        ' string too!", "numberField": 6, "nullField": null}, {"stringField":'
        ' "This is a string also!", "numberField": 7, "nullField": null}]}'
    )
    _ = write(
        cache,
        (
            "{ id stringField numberField nullField nestedArray { stringField"
            " numberField nullField } }"
        ),
        data,
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedArray": [{"stringField": "This is a'
            ' string too!", "numberField": 6, "nullField": null},'
            ' {"stringField": "This is a string also!", "numberField": 7,'
            ' "nullField": null}]}}'
        ),
    )


def test_normalizes_a_nested_array_without_ids_and_a_null_item() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        (
            "{ id stringField numberField nullField nestedArray { stringField"
            " numberField nullField } }"
        ),
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "nestedArray": [null, {"stringField": "This'
            ' is a string also!", "numberField": 7, "nullField": null}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedArray": [null, {"stringField": "This is'
            ' a string also!", "numberField": 7, "nullField": null}]}}'
        ),
    )


def test_normalizes_an_array_of_non_objects() raises:
    var cache = _id_cache()
    _ = write(
        cache,
        "{ id stringField numberField nullField simpleArray }",
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "simpleArray": ["one", "two", "three"]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "simpleArray": ["one", "two", "three"]}}'
        ),
    )


def test_normalizes_an_array_of_non_objects_with_null() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        "{ id stringField numberField nullField simpleArray }",
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "simpleArray": [null, "two", "three"]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "simpleArray": [null, "two", "three"]}}'
        ),
    )


def test_refuses_to_normalize_objects_with_nullish_id_fields() raises:
    # Upstream also writes `{ id: void 0 }`, which JSON cannot hold; an
    # object without `id` is the same write.
    var cache = InMemoryCache()
    _ = write(
        cache,
        "query { objects { id text } }",
        (
            '{"objects": [{"__typename": "Object", "text": "a", "id": 123},'
            ' {"__typename": "Object", "text": "b", "id": null}, {"__typename":'
            ' "Object", "text": "c"}, {"__typename": "Object", "text": "d",'
            ' "id": 0}, {"__typename": "Object", "text": "e", "id": ""},'
            ' {"__typename": "Object", "text": "f", "id": false},'
            ' {"__typename": "Object", "text": "g"}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Object:123": {"__typename": "Object", "id": 123, "text": "a"},'
            ' "Object:0": {"__typename": "Object", "id": 0, "text": "d"},'
            ' "Object:": {"__typename": "Object", "id": "", "text": "e"},'
            ' "Object:false": {"__typename": "Object", "id": false, "text":'
            ' "f"}, "ROOT_QUERY": {"__typename": "Query", "objects": [{"__ref":'
            ' "Object:123"}, {"__typename": "Object", "id": null, "text": "b"},'
            ' {"__typename": "Object", "text": "c"}, {"__ref": "Object:0"},'
            ' {"__ref": "Object:"}, {"__ref": "Object:false"}, {"__typename":'
            ' "Object", "text": "g"}]}}'
        ),
    )
    assert_read(
        cache,
        gql("query { objects { text } }"),
        (
            '{"objects": [{"__typename": "Object", "text": "a"}, {"__typename":'
            ' "Object", "text": "b"}, {"__typename": "Object", "text": "c"},'
            ' {"__typename": "Object", "text": "d"}, {"__typename": "Object",'
            ' "text": "e"}, {"__typename": "Object", "text": "f"},'
            ' {"__typename": "Object", "text": "g"}]}'
        ),
    )


def test_refuses_to_normalize_objects_with_nullish_underscore_id_fields() raises:
    var cache = InMemoryCache()
    _ = write(
        cache,
        "query { objects { _id text } }",
        (
            '{"objects": [{"__typename": "Object", "text": "a", "_id": 123},'
            ' {"__typename": "Object", "text": "b", "_id": null},'
            ' {"__typename": "Object", "text": "c"}, {"__typename": "Object",'
            ' "text": "d", "_id": 0}, {"__typename": "Object", "text": "e",'
            ' "_id": ""}, {"__typename": "Object", "text": "f", "_id": false},'
            ' {"__typename": "Object", "text": "g"}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Object:123": {"__typename": "Object", "_id": 123, "text": "a"},'
            ' "Object:0": {"__typename": "Object", "_id": 0, "text": "d"},'
            ' "Object:": {"__typename": "Object", "_id": "", "text": "e"},'
            ' "Object:false": {"__typename": "Object", "_id": false, "text":'
            ' "f"}, "ROOT_QUERY": {"__typename": "Query", "objects": [{"__ref":'
            ' "Object:123"}, {"__typename": "Object", "_id": null, "text":'
            ' "b"}, {"__typename": "Object", "text": "c"}, {"__ref":'
            ' "Object:0"}, {"__ref": "Object:"}, {"__ref": "Object:false"},'
            ' {"__typename": "Object", "text": "g"}]}}'
        ),
    )
    assert_read(
        cache,
        gql("query { objects { text } }"),
        (
            '{"objects": [{"__typename": "Object", "text": "a"}, {"__typename":'
            ' "Object", "text": "b"}, {"__typename": "Object", "text": "c"},'
            ' {"__typename": "Object", "text": "d"}, {"__typename": "Object",'
            ' "text": "e"}, {"__typename": "Object", "text": "f"},'
            ' {"__typename": "Object", "text": "g"}]}'
        ),
    )


def test_normalizes_an_object_in_different_paths_twice() raises:
    var cache = _id_cache()
    _ = write(
        cache,
        "{ id object1 { id stringField } object2 { id numberField } }",
        (
            '{"id": "a", "object1": {"id": "aa", "stringField": "string"},'
            ' "object2": {"id": "aa", "numberField": 1}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "a", "object1":'
            ' {"__ref": "aa"}, "object2": {"__ref": "aa"}}, "aa": {"id": "aa",'
            ' "stringField": "string", "numberField": 1}}'
        ),
    )


def test_normalizes_an_object_in_different_array_paths_twice() raises:
    var cache = _id_cache()
    _ = write(
        cache,
        (
            "{ id array1 { id stringField obj { id stringField } } array2 { id"
            " stringField obj { id numberField } } }"
        ),
        (
            '{"id": "a", "array1": [{"id": "aa", "stringField": "string",'
            ' "obj": {"id": "aaa", "stringField": "string"}}], "array2":'
            ' [{"id": "ab", "stringField": "string2", "obj": {"id": "aaa",'
            ' "numberField": 1}}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "a", "array1":'
            ' [{"__ref": "aa"}], "array2": [{"__ref": "ab"}]}, "aa": {"id":'
            ' "aa", "stringField": "string", "obj": {"__ref": "aaa"}}, "ab":'
            ' {"id": "ab", "stringField": "string2", "obj": {"__ref": "aaa"}},'
            ' "aaa": {"id": "aaa", "stringField": "string", "numberField": 1}}'
        ),
    )


def test_normalizes_an_object_in_the_same_array_path_twice() raises:
    var cache = _id_cache()
    _ = write(
        cache,
        "{ id array1 { id stringField obj { id stringField numberField } } }",
        (
            '{"id": "a", "array1": [{"id": "aa", "stringField": "string",'
            ' "obj": {"id": "aaa", "stringField": "string", "numberField": 1}},'
            ' {"id": "ab", "stringField": "string2", "obj": {"id": "aaa",'
            ' "stringField": "should not be written", "numberField": 2}}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "a", "array1":'
            ' [{"__ref": "aa"}, {"__ref": "ab"}]}, "aa": {"id": "aa",'
            ' "stringField": "string", "obj": {"__ref": "aaa"}}, "ab": {"id":'
            ' "ab", "stringField": "string2", "obj": {"__ref": "aaa"}}, "aaa":'
            ' {"id": "aaa", "stringField": "string", "numberField": 1}}'
        ),
    )


def test_merges_nodes() raises:
    var cache = _id_cache()
    _ = write(
        cache,
        "{ id numberField nullField }",
        '{"id": "abcd", "numberField": 5, "nullField": null}',
    )
    _ = write(
        cache,
        "{ id stringField nullField }",
        '{"id": "abcd", "stringField": "This is a string!", "nullField": null}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "numberField": 5, "nullField": null, "stringField": "This is a'
            ' string!"}}'
        ),
    )


def test_normalizes_a_nested_object_that_returns_null() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        (
            "{ id stringField numberField nullField nestedObj { id stringField"
            " numberField nullField } }"
        ),
        (
            '{"id": "abcd", "stringField": "This is a string!", "numberField":'
            ' 5, "nullField": null, "nestedObj": null}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "id": "abcd",'
            ' "stringField": "This is a string!", "numberField": 5,'
            ' "nullField": null, "nestedObj": null}}'
        ),
    )


def test_normalizes_an_object_with_an_id_and_no_extension() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        '{ people_one(id: "5") { id stringField } }',
        '{"people_one": {"id": "abcd", "stringField": "This is a string!"}}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query",'
            ' "people_one({\\"id\\":\\"5\\"})": {"id": "abcd", "stringField":'
            ' "This is a string!"}}}'
        ),
    )


def _store_key(mutation: StringSlice, variables: StringSlice) raises -> String:
    """`storeKeyNameFromField` of the first field of an operation."""
    var document = gql(mutation)
    var values = Values()
    var given = json(variables)
    var vars = values.from_json(given, given.root)
    var operation = document.first_child(document.root)
    var field = document.first_child(
        document.child(operation, Role.SELECTION_SET)
    )
    return store_key_name_from_field(document, field, values, vars)


def test_serializes_inline_and_variable_input_the_same() raises:
    assert_equal(
        _store_key(
            "mutation mut($in: Int!) { mut(inline: 5, variable: $in) { id } }",
            '{"in": 5}',
        ),
        'mut({"inline":5,"variable":5})',
    )
    assert_equal(
        _store_key(
            (
                "mutation mut($in: Float!) { mut(inline: 5.5, variable: $in) {"
                " id } }"
            ),
            '{"in": 5.5}',
        ),
        'mut({"inline":5.5,"variable":5.5})',
    )
    assert_equal(
        _store_key(
            (
                'mutation mut($in: String!) { mut(inline: "abc", variable: $in)'
                " { id } }"
            ),
            '{"in": "abc"}',
        ),
        'mut({"inline":"abc","variable":"abc"})',
    )
    assert_equal(
        _store_key(
            (
                "mutation mut($in: Array!) { mut(inline: [1, 2], variable: $in)"
                " { id } }"
            ),
            '{"in": [1, 2]}',
        ),
        'mut({"inline":[1,2],"variable":[1,2]})',
    )
    assert_equal(
        _store_key(
            (
                "mutation mut($in: Object!) { mut(inline: { a: 1 }, variable:"
                " $in) { id } }"
            ),
            '{"in": {"a": 1}}',
        ),
        'mut({"inline":{"a":1},"variable":{"a":1}})',
    )
    assert_equal(
        _store_key(
            (
                "mutation mut($in: Boolean!) { mut(inline: true, variable: $in)"
                " { id } }"
            ),
            '{"in": true}',
        ),
        'mut({"inline":true,"variable":true})',
    )


def five(mut context: KeyFieldsContext) raises -> String:
    """`dataIdFromObject() { return "5" }`."""
    return "5"


def test_normalizes_a_mutation_with_object_and_array_parameters() raises:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = five
    var cache = InMemoryCache(config)
    _ = cache.write_query(
        gql(
            "mutation some_mutation($nil: ID, $in: Object) {"
            ' some_mutation(input: { id: "5" arr: [1, { a: "b" }] obj: { a:'
            ' "b" } num: 5.5 nil: $nil bo: true }) { id }'
            " some_mutation_with_variables(input: $in) { id } }"
        ),
        json(
            '{"some_mutation": {"id": "id"}, "some_mutation_with_variables":'
            ' {"id": "id"}}'
        ),
        json(
            '{"nil": null, "in": {"id": "5", "arr": [1, {"a": "b"}], "obj":'
            ' {"a": "b"}, "num": 5.5, "nil": null, "bo": true}}'
        ),
        "5",
    )
    assert_extract(
        cache,
        (
            '{"5": {"id": "id",'
            ' "some_mutation({\\"input\\":{\\"arr\\":[1,{\\"a\\":\\"b\\"}],\\"bo\\":true,\\"id\\":\\"5\\",\\"nil\\":null,\\"num\\":5.5,\\"obj\\":{\\"a\\":\\"b\\"}}})":'
            ' {"__ref": "5"},'
            ' "some_mutation_with_variables({\\"input\\":{\\"arr\\":[1,{\\"a\\":\\"b\\"}],\\"bo\\":true,\\"id\\":\\"5\\",\\"nil\\":null,\\"num\\":5.5,\\"obj\\":{\\"a\\":\\"b\\"}}})":'
            ' {"__ref": "5"}}, "__META": {"extraRootIds": ["5"]}}'
        ),
    )


def test_escapes_generated_ids() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        "query { author { firstName lastName } }",
        '{"author": {"firstName": "John", "lastName": "Smith"}}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "author": {"firstName":'
            ' "John", "lastName": "Smith"}}}'
        ),
    )


def test_escapes_real_ids() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        "query { author { firstName id __typename } }",
        (
            '{"author": {"firstName": "John", "id": "129", "__typename":'
            ' "Author"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "author": {"__ref":'
            ' "Author__129"}}, "Author__129": {"firstName": "John", "id":'
            ' "129", "__typename": "Author"}}'
        ),
    )


def test_does_not_escape_json_blobs() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        "query { author { info id __typename } }",
        (
            '{"author": {"info": {"name": "John"}, "id": "129", "__typename":'
            ' "Author"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "author": {"__ref":'
            ' "Author__129"}}, "Author__129": {"__typename": "Author", "id":'
            ' "129", "info": {"name": "John"}}}'
        ),
    )


def prefer_incoming(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `author` merge function of "should not merge unidentified data
    when replacing with ID reference", with its checks."""
    if existing != NO_VALUE:
        assert_false(options.is_reference(existing))
        var typename = options.read_field_from("__typename", existing)
        assert_equal(String(options.cache[].values.text(typename)), "Author")
        assert_true(options.is_reference(incoming))
        typename = options.read_field_from("__typename", incoming)
        assert_equal(String(options.cache[].values.text(typename)), "Author")
    return incoming


def test_does_not_merge_unidentified_data_with_an_id_reference() raises:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = typename_id
    var query_policy = TypePolicy()
    var author = FieldPolicy()
    author.merge = Merge(prefer_incoming)
    query_policy.fields["author"] = author^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { author { firstName lastName __typename } }",
        (
            '{"author": {"firstName": "John", "lastName": "Smith",'
            ' "__typename": "Author"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "author": {"firstName":'
            ' "John", "lastName": "Smith", "__typename": "Author"}}}'
        ),
    )
    _ = write(
        cache,
        "query { author { firstName id __typename } }",
        (
            '{"author": {"firstName": "John", "id": "129", "__typename":'
            ' "Author"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Author__129": {"firstName": "John", "id": "129", "__typename":'
            ' "Author"}, "ROOT_QUERY": {"__typename": "Query", "author":'
            ' {"__ref": "Author__129"}}}'
        ),
    )


def test_merges_fragment_fields_along_multiple_paths() raises:
    var config = InMemoryCacheConfig()
    config.type_policies["Container"] = TypePolicy()
    var cache = InMemoryCache(config)
    var query = gql(
        'query Query { item(id: "123") { id value { ...ContainerFragment } } }'
        " fragment ContainerFragment on Container { value { ...ValueFragment"
        " item { id value { text } } } } fragment ValueFragment on Value {"
        " item { ...ItemFragment } } fragment ItemFragment on Item { value {"
        " value { __typename } } }"
    )
    _ = cache.write_query(
        query,
        json(
            '{"item": {"__typename": "Item", "id":'
            ' "0f47f85d-8081-466e-9121-c94069a77c3e", "value": {"__typename":'
            ' "Container", "value": {"__typename": "Value", "item":'
            ' {"__typename": "Item", "id":'
            ' "6dc3530b-6731-435e-b12a-0089d0ae05ac", "value": {"__typename":'
            ' "Container", "text": "Hello World", "value": {"__typename":'
            ' "Value"}}}}}}}'
        ),
    )
    # The expected texts are the Node.js output of Apollo Client 4.3.3.
    assert_read_exact(
        cache,
        query,
        (
            '{"item":{"__typename":"Item","id":"0f47f85d-8081-466e-9121-c94069a77c3e","value":{"__typename":"Container","value":{"__typename":"Value","item":{"__typename":"Item","value":{"__typename":"Container","value":{"__typename":"Value"},"text":"Hello'
            ' World"},"id":"6dc3530b-6731-435e-b12a-0089d0ae05ac"}}}}}'
        ),
    )
    assert_extract_exact(
        cache,
        (
            '{"Item:6dc3530b-6731-435e-b12a-0089d0ae05ac":{"__typename":"Item","value":{"__typename":"Container","value":{"__typename":"Value"},"text":"Hello'
            ' World"},"id":"6dc3530b-6731-435e-b12a-0089d0ae05ac"},"Item:0f47f85d-8081-466e-9121-c94069a77c3e":{"__typename":"Item","id":"0f47f85d-8081-466e-9121-c94069a77c3e","value":{"__typename":"Container","value":{"__typename":"Value","item":{"__ref":"Item:6dc3530b-6731-435e-b12a-0089d0ae05ac"}}}},"ROOT_QUERY":{"__typename":"Query","item({\\"id\\":\\"123\\"})":{"__ref":"Item:0f47f85d-8081-466e-9121-c94069a77c3e"}}}'
        ),
    )


def offset_merge(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `cities` merge function of the #8600 regression test."""
    if options.args == NO_VALUE:
        return incoming
    ref values = options.cache[].values
    var items = values.array_items(existing)
    var offset = 0
    var given = values.get(options.args, "offset")
    if values.kind(given) == ValueKind.NUMBER:
        offset = Int(atol(values.text(given)))
    var index = 0
    while index < values.length(incoming):
        while len(items) <= offset + index:
            items.append(UNDEFINED_VALUE)
        items[offset + index] = values.item(incoming, index)
        index += 1
    return values.add_array(items)


def test_regression_issue_8600() raises:
    var config = InMemoryCacheConfig()
    var country = TypePolicy()
    var cities = FieldPolicy()
    cities.key_args = KeyArgs.parse('["size"]')
    cities.merge = Merge(offset_merge)
    country.fields["cities"] = cities^
    config.type_policies["Country"] = country^
    var city_info = TypePolicy()
    city_info.merge = Merge(True)
    config.type_policies["CityInfo"] = city_info^
    var cache = InMemoryCache(config)
    var query = gql(
        "query GetCountries { countries { id ...WithSmallCities"
        " ...WithAirQuality } } fragment WithSmallCities on Country {"
        " biggestCity { id } smallCities: cities(size: SMALL) { id } }"
        " fragment WithAirQuality on Country { biggestCity { id info {"
        " airQuality } } }"
    )
    var countries = (
        '{"countries": [{"__typename": "Country", "id": 123, "biggestCity":'
        ' {"__typename": "City", "id": 234, "info": {"__typename":'
        ' "CityInfo", "airQuality": 0}}, "smallCities": [{"__typename":'
        ' "City", "id": 345}]}]}'
    )
    _ = cache.write_query(query, json(countries))
    assert_extract(
        cache,
        (
            '{"City:234": {"__typename": "City", "id": 234, "info":'
            ' {"__typename": "CityInfo", "airQuality": 0}}, "City:345":'
            ' {"__typename": "City", "id": 345}, "Country:123": {"__typename":'
            ' "Country", "id": 123, "biggestCity": {"__ref": "City:234"},'
            ' "cities:{\\"size\\":\\"SMALL\\"}": [{"__ref": "City:345"}]},'
            ' "ROOT_QUERY": {"__typename": "Query", "countries": [{"__ref":'
            ' "Country:123"}]}}'
        ),
    )
    assert_read(cache, query, countries)


def test_respects_id_fields_added_by_fragments() raises:
    var config = InMemoryCacheConfig()
    var shared: List[String] = ["AType"]
    config.possible_types["AShared"] = shared^
    var cache = InMemoryCache(config)
    var query = gql(
        "query ABCQuery { __typename a { __typename id ...SharedFragment b {"
        " __typename c { __typename title titleSize } } } } fragment"
        " SharedFragment on AShared { __typename b { __typename id c {"
        " __typename } } }"
    )
    _ = cache.write_query(
        query,
        json(
            '{"__typename": "Query", "a": {"__typename": "AType", "id":'
            ' "a-id", "b": [{"__typename": "BType", "id": "b-id", "c":'
            ' {"__typename": "CType", "title": "Your experience",'
            ' "titleSize": null}}]}}'
        ),
    )
    assert_read_exact(
        cache,
        query,
        (
            '{"__typename":"Query","a":{"__typename":"AType","id":"a-id","b":[{"__typename":"BType","id":"b-id","c":{"__typename":"CType","title":"Your'
            ' experience","titleSize":null}}]}}'
        ),
    )
    assert_extract_exact(
        cache,
        (
            '{"BType:b-id":{"__typename":"BType","id":"b-id","c":{"__typename":"CType","title":"Your'
            ' experience","titleSize":null}},"AType:a-id":{"__typename":"AType","id":"a-id","b":[{"__ref":"BType:b-id"}]},"ROOT_QUERY":{"__typename":"Query","a":{"__ref":"AType:a-id"}}}'
        ),
    )


def check_author_union(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `author` merge function of "should allow a union of objects of
    a different type": it checks each of the three merges by its values."""
    ref values = options.cache[].values
    var placeholder = '{"__typename":"Placeholder","hello":"Foo"}'
    if existing == NO_VALUE:
        assert_false(options.is_reference(incoming))
        assert_equal(values.stringify(incoming), placeholder)
    elif not options.is_reference(existing):
        assert_equal(values.stringify(existing), placeholder)
        assert_true(options.is_reference(incoming))
        var typename = options.read_field_from("__typename", incoming)
        assert_equal(String(values.text(typename)), "Author")
    else:
        var typename = options.read_field_from("__typename", existing)
        assert_equal(String(values.text(typename)), "Author")
        assert_equal(values.stringify(incoming), placeholder)
    return incoming


def test_allows_a_union_when_overwriting_a_generated_id() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var author = FieldPolicy()
    author.merge = Merge(check_author_union)
    query_policy.fields["author"] = author^
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    var query = (
        "query { author { ... on Author { firstName lastName id __typename }"
        " ... on Placeholder { hello __typename } } }"
    )
    var placeholder = (
        '{"author": {"hello": "Foo", "__typename": "Placeholder"}}'
    )
    _ = write(cache, query, placeholder)
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "author": {"hello": "Foo",'
            ' "__typename": "Placeholder"}}}'
        ),
    )
    _ = write(
        cache,
        query,
        (
            '{"author": {"firstName": "John", "lastName": "Smith", "id": "129",'
            ' "__typename": "Author"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Author:129": {"firstName": "John", "lastName": "Smith", "id":'
            ' "129", "__typename": "Author"}, "ROOT_QUERY": {"__typename":'
            ' "Query", "author": {"__ref": "Author:129"}}}'
        ),
    )
    _ = write(cache, query, placeholder)
    assert_extract(
        cache,
        (
            '{"Author:129": {"firstName": "John", "lastName": "Smith", "id":'
            ' "129", "__typename": "Author"}, "ROOT_QUERY": {"__typename":'
            ' "Query", "author": {"hello": "Foo", "__typename":'
            ' "Placeholder"}}}'
        ),
    )


def test_does_not_swallow_errors_other_than_field_errors() raises:
    var cache = _typename_cache()
    with assert_raises(contains="No fragment named notARealFragment"):
        _ = write(
            cache,
            "query { ...notARealFragment fortuneCookie }",
            '{"fortuneCookie": "Star Wars unit tests are boring"}',
        )


def test_handles_the_connection_directive() raises:
    var cache = _typename_cache()
    _ = write(
        cache,
        '{ books(skip: 0, limit: 2) @connection(key: "abc") { name } }',
        '{"books": [{"name": "abcd"}]}',
    )
    _ = write(
        cache,
        '{ books(skip: 2, limit: 4) @connection(key: "abc") { name } }',
        '{"books": [{"name": "efgh"}]}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "books:abc": [{"name":'
            ' "efgh"}]}}'
        ),
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
    _ = write(
        cache,
        "{ books(skip: 0, limit: 2) { name } }",
        '{"books": [{"name": "abcd"}]}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "books:abc": [{"name":'
            ' "abcd"}]}}'
        ),
    )
    _ = write(
        cache,
        "{ books(skip: 2, limit: 4) { name } }",
        '{"books": [{"name": "efgh"}]}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "books:abc": [{"name":'
            ' "efgh"}]}}'
        ),
    )


def test_keeps_the_reference_when_a_mixed_inlined_type_changes() raises:
    var cache = _typename_cache()
    var query = "query { animals { species { name } } }"
    _ = write(
        cache,
        query,
        (
            '{"animals": [{"__typename": "Animal", "species": {"__typename":'
            ' "Cat", "name": "cat"}}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "animals": [{"__typename":'
            ' "Animal", "species": {"__typename": "Cat", "name": "cat"}}]}}'
        ),
    )
    _ = write(
        cache,
        query,
        (
            '{"animals": [{"__typename": "Animal", "species": {"__typename":'
            ' "Dog", "name": "dog"}}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "animals": [{"__typename":'
            ' "Animal", "species": {"__typename": "Dog", "name": "dog"}}]}}'
        ),
    )


def test_drops_the_reference_when_an_inlined_type_becomes_normalized() raises:
    var cache = _typename_cache()
    var query = "query { animals { species { id name } } }"
    _ = write(
        cache,
        query,
        (
            '{"animals": [{"__typename": "Animal", "species": {"__typename":'
            ' "Cat", "name": "cat"}}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "animals": [{"__typename":'
            ' "Animal", "species": {"__typename": "Cat", "name": "cat"}}]}}'
        ),
    )
    _ = write(
        cache,
        query,
        (
            '{"animals": [{"__typename": "Animal", "species": {"id":'
            ' "dog-species", "__typename": "Dog", "name": "dog"}}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Dog__dog-species": {"id": "dog-species", "__typename": "Dog",'
            ' "name": "dog"}, "ROOT_QUERY": {"__typename": "Query", "animals":'
            ' [{"__typename": "Animal", "species": {"__ref":'
            ' "Dog__dog-species"}}]}}'
        ),
    )


def merge_accounts(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `Account` merge function: `mergeObjects`, with the checks of the
    recorded merges of upstream."""
    var merged = options.merge_objects(existing, incoming)
    if options.is_reference(existing) or options.is_reference(incoming):
        assert_true(options.is_reference(merged))
        assert_equal(
            String(options.cache[].values.ref_text(merged)), "Account:12345"
        )
    return merged


def test_does_not_merge_a_reference_as_a_store_object() raises:
    var config = InMemoryCacheConfig()
    var account = TypePolicy()
    account.merge = Merge(merge_accounts)
    config.type_policies["Account"] = account^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { account { contact location } }",
        (
            '{"account": {"__typename": "Account", "contact":'
            ' "billing@example.com", "location": "Exampleville, Ohio"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "account": {"__typename":'
            ' "Account", "contact": "billing@example.com", "location":'
            ' "Exampleville, Ohio"}}}'
        ),
    )
    _ = write(
        cache,
        "query { account { contact } }",
        (
            '{"account": {"__typename": "Account", "id": 12345, "contact":'
            ' "support@example.com"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Account:12345": {"__typename": "Account", "id": 12345,'
            ' "contact": "support@example.com", "location": "Exampleville,'
            ' Ohio"}, "ROOT_QUERY": {"__typename": "Query", "account":'
            ' {"__ref": "Account:12345"}}}'
        ),
    )
    _ = write(
        cache,
        "query { account { location } }",
        (
            '{"account": {"__typename": "Account", "location": "Nowhere, New'
            ' Mexico"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"Account:12345": {"__typename": "Account", "id": 12345,'
            ' "contact": "support@example.com", "location": "Nowhere, New'
            ' Mexico"}, "ROOT_QUERY": {"__typename": "Query", "account":'
            ' {"__ref": "Account:12345"}}}'
        ),
    )


def test_write_fragment_infers_root_query() raises:
    var cache = InMemoryCache()
    var id = cache.write_fragment(
        gql("fragment RootField on Query { field }"),
        json('{"__typename": "Query", "field": "value"}'),
    )
    assert_equal(id, "ROOT_QUERY")
    assert_extract(
        cache, '{"ROOT_QUERY": {"__typename": "Query", "field": "value"}}'
    )


def test_raises_when_it_cannot_identify_the_result_object() raises:
    var cache = InMemoryCache()
    with assert_raises(contains='Could not identify object {\n  "count": 1\n}'):
        _ = cache.write_fragment(
            gql("fragment Count on Counter { count }"), json('{"count": 1}')
        )


def test_user_objects_can_have_typename_subscription() raises:
    var config = InMemoryCacheConfig()
    var subscription = TypePolicy()
    subscription.key_fields = KeyFields.parse('["subId"]')
    config.type_policies["Subscription"] = subscription^
    var cache = InMemoryCache(config)
    var query = "query { subscriptions { __typename subscriber { name } } }"
    _ = write(
        cache,
        query,
        (
            '{"subscriptions": [{"__typename": "Subscription", "subId": 1,'
            ' "subscriber": {"name": "Alice"}}, {"__typename": "Subscription",'
            ' "subId": 2, "subscriber": {"name": "Bob"}}, {"__typename":'
            ' "Subscription", "subId": 3, "subscriber": {"name":'
            ' "Clytemnestra"}}]}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Subscription:{\\"subId\\":1}":{"__typename":"Subscription","subscriber":{"name":"Alice"},"subId":1},"Subscription:{\\"subId\\":2}":{"__typename":"Subscription","subscriber":{"name":"Bob"},"subId":2},"Subscription:{\\"subId\\":3}":{"__typename":"Subscription","subscriber":{"name":"Clytemnestra"},"subId":3},"ROOT_QUERY":{"__typename":"Query","subscriptions":[{"__ref":"Subscription:{\\"subId\\":1}"},{"__ref":"Subscription:{\\"subId\\":2}"},{"__ref":"Subscription:{\\"subId\\":3}"}]}}',
    )
    assert_read_exact(
        cache,
        gql(query),
        '{"subscriptions":[{"__typename":"Subscription","subscriber":{"name":"Alice"}},{"__typename":"Subscription","subscriber":{"name":"Bob"}},{"__typename":"Subscription","subscriber":{"name":"Clytemnestra"}}]}',
    )


def test_user_objects_can_have_typename_mutation() raises:
    var config = InMemoryCacheConfig()
    var mutation = TypePolicy()
    mutation.key_fields = KeyFields.parse('["gene", ["id"], "name"]')
    config.type_policies["Mutation"] = mutation^
    var gene = TypePolicy()
    gene.key_fields = KeyFields.parse('["id"]')
    config.type_policies["Gene"] = gene^
    var cache = InMemoryCache(config)
    var query = "query { mutations { __typename gene { id } name } }"
    _ = write(
        cache,
        query,
        (
            '{"mutations": [{"__typename": "Mutation", "gene": {"__typename":'
            ' "Gene", "id": "SLC45A2"}, "name": "albinism"}, {"__typename":'
            ' "Mutation", "gene": {"__typename": "Gene", "id": "SNAI2"},'
            ' "name": "piebaldism"}]}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"Gene:{\\"id\\":\\"SLC45A2\\"}":{"__typename":"Gene","id":"SLC45A2"},"Mutation:{\\"gene\\":{\\"id\\":\\"SLC45A2\\"},\\"name\\":\\"albinism\\"}":{"__typename":"Mutation","gene":{"__ref":"Gene:{\\"id\\":\\"SLC45A2\\"}","id":"SLC45A2"},"name":"albinism"},"Gene:{\\"id\\":\\"SNAI2\\"}":{"__typename":"Gene","id":"SNAI2"},"Mutation:{\\"gene\\":{\\"id\\":\\"SNAI2\\"},\\"name\\":\\"piebaldism\\"}":{"__typename":"Mutation","gene":{"__ref":"Gene:{\\"id\\":\\"SNAI2\\"}","id":"SNAI2"},"name":"piebaldism"},"ROOT_QUERY":{"__typename":"Query","mutations":[{"__ref":"Mutation:{\\"gene\\":{\\"id\\":\\"SLC45A2\\"},\\"name\\":\\"albinism\\"}"},{"__ref":"Mutation:{\\"gene\\":{\\"id\\":\\"SNAI2\\"},\\"name\\":\\"piebaldism\\"}"}]}}',
    )
    assert_read_exact(
        cache,
        gql(query),
        '{"mutations":[{"__typename":"Mutation","gene":{"__typename":"Gene","id":"SLC45A2"},"name":"albinism"},{"__typename":"Mutation","gene":{"__typename":"Gene","id":"SNAI2"},"name":"piebaldism"}]}',
    )


def test_writes_data_without_validating_its_shape() raises:
    # Upstream also checks the console; this port prints no warnings.
    var cache = _id_cache()
    _ = write(
        cache,
        "query { todos { id name description } }",
        '{"todos": [{"id": "1", "name": "Todo 1"}]}',
    )
    assert_extract(
        cache,
        (
            '{"1": {"id": "1", "name": "Todo 1"}, "ROOT_QUERY": {"__typename":'
            ' "Query", "todos": [{"__ref": "1"}]}}'
        ),
    )


def test_writes_wrong_data_with_empty_possible_types() raises:
    var config = InMemoryCacheConfig()
    config.data_id_from_object = get_id_field
    config.possible_types = Dict[String, List[String]]()
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { todos { id name description } }",
        '{"todos": [{"id": "1", "name": "Todo 1"}]}',
    )
    assert_extract(
        cache,
        (
            '{"1": {"id": "1", "name": "Todo 1"}, "ROOT_QUERY": {"__typename":'
            ' "Query", "todos": [{"__ref": "1"}]}}'
        ),
    )


def test_replaces_scalar_fields_that_hold_objects() raises:
    var cache = InMemoryCache()
    var query = 'query { someJSON currentTime(tz: "UTC-5") }'
    _ = write(
        cache,
        query,
        (
            '{"someJSON": {"oyez": 3, "foos": ["bar", "baz"]}, "currentTime":'
            ' {"localeString": "9/25/2020, 1:08:33 PM"}}'
        ),
    )
    assert_extract_exact(
        cache,
        (
            '{"ROOT_QUERY":{"__typename":"Query","someJSON":{"oyez":3,"foos":["bar","baz"]},"currentTime({\\"tz\\":\\"UTC-5\\"})":{"localeString":"9/25/2020,'
            ' 1:08:33 PM"}}}'
        ),
    )
    _ = write(
        cache,
        query,
        (
            '{"someJSON": {"qwer": "upper", "asdf": "middle", "zxcv": "lower"},'
            ' "currentTime": {"msSinceEpoch": 1601053713081}}'
        ),
    )
    assert_extract_exact(
        cache,
        '{"ROOT_QUERY":{"__typename":"Query","someJSON":{"qwer":"upper","asdf":"middle","zxcv":"lower"},"currentTime({\\"tz\\":\\"UTC-5\\"})":{"msSinceEpoch":1601053713081}}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
