# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the cache writes of a client: `gql_client.query_info`.

The cases port the cache part of these Apollo Client 4.3.3 (ae0dfce)
cases, which run `ApolloClient` with a link:

- `src/incremental/handlers/__tests__/graphql17Alpha9/defer.test.ts` and
  `defer20220824/defer.test.ts`: "merges cache updates that happen
  concurrently" and "returns error on initial result".
- `src/core/__tests__/client.watchQuery/streamGraphQL17Alpha9.test.ts`:
  "provides streamFieldInfo to merge functions".
- `src/__tests__/graphqlSubscriptions.ts`: "provides extensions to merge
  functions", "should not cache subscription data if a `no-cache` fetch
  policy is used" and "emits an error if the result has GraphQL errors".
- `src/cache/inmemory/__tests__/cache.writeQuery/extensions.test.ts`.

A case gives the payloads of the upstream link to `mark_result` or
`mark_subscription_result`, and checks the data, the data state and the
cache. The upstream checks of `loading`, `networkStatus` and the
emissions of `ObservableQuery` are not ported: `ObservableQuery` is not
ported. A thin Mojo function cannot count its calls, so each merge
function checks its arguments instead of `toHaveBeenCalledWith`.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
)
from gql_client.incremental import (
    Defer20220824Handler,
    GraphQL17Alpha9Handler,
    StreamArrayState,
    StreamFieldInfo,
    StreamInfo,
    StreamInfoEntry,
    path_key_append,
)
from gql_client.policies import FieldPolicy, Merge
from gql_client.query_info import (
    CacheWriteBehavior,
    DataState,
    ErrorPolicy,
    as_query,
    mark_result,
    mark_subscription_result,
    subscribe_result,
    with_data,
)
from gql_client.values import NO_VALUE
from gql_json.value import JsonDocument

from _helpers import assert_extract, gql, json, text_of
from _policy_helpers import add_field

comptime _CONCURRENT = """
    query HeroNameQuery {
      hero {
        id
        job
        ... @defer {
          name
        }
      }
    }
"""


def test_merges_cache_updates_that_happen_concurrently() raises:
    """Merges cache updates that happen concurrently (graphql17Alpha9)."""
    var cache = InMemoryCache()
    var handler = GraphQL17Alpha9Handler()
    var query = cache.transform_document(
        handler.transform_document(gql(_CONCURRENT))
    )
    var request = handler.start_request()
    var first = mark_result(
        cache,
        request,
        query,
        json(
            '{"data":{"hero":{"__typename":"Hero","id":"1","job":"Farmer"}},'
            '"pending":[{"id":"0","path":["hero"]}],"hasNext":true}'
        ),
    )
    assert_equal(
        text_of(first.result),
        '{"data":{"hero":{"__typename":"Hero","id":"1","job":"Farmer"}}}',
    )
    assert_true(first.data_state == DataState.STREAMING)
    _ = cache.write_fragment(
        gql("fragment HeroJob on Hero { job }"),
        json('{"job":"Jedi"}'),
        "Hero:1",
    )
    var last = mark_result(
        cache,
        request,
        query,
        json(
            '{"incremental":[{"data":{"name":"Luke"},"id":"0"}],'
            '"completed":[{"id":"0"}],"hasNext":false}'
        ),
    )
    assert_equal(
        text_of(last.result),
        (
            '{"data":{"hero":{"__typename":"Hero","id":"1","job":"Jedi",'
            '"name":"Luke"}}}'
        ),
    )
    assert_true(last.data_state == DataState.COMPLETE)


def test_merges_cache_updates_that_happen_concurrently_defer20220824() raises:
    """Merges cache updates that happen concurrently (defer20220824)."""
    var cache = InMemoryCache()
    var handler = Defer20220824Handler()
    var query = cache.transform_document(gql(_CONCURRENT))
    var request = handler.start_request()
    var first = mark_result(
        cache,
        request,
        query,
        json(
            '{"data":{"hero":{"__typename":"Hero","id":"1","job":"Farmer"}},'
            '"hasNext":true}'
        ),
    )
    assert_true(first.data_state == DataState.STREAMING)
    _ = cache.write_fragment(
        gql("fragment HeroJob on Hero { job }"),
        json('{"job":"Jedi"}'),
        "Hero:1",
    )
    var last = mark_result(
        cache,
        request,
        query,
        json(
            '{"incremental":[{"data":{"name":"Luke"},"path":["hero"]}],'
            '"hasNext":false}'
        ),
    )
    assert_equal(
        text_of(last.result),
        (
            '{"data":{"hero":{"__typename":"Hero","id":"1","job":"Jedi",'
            '"name":"Luke"}}}'
        ),
    )
    assert_true(last.data_state == DataState.COMPLETE)


def test_returns_error_on_initial_result() raises:
    """Returns error on initial result, with `errorPolicy: "all"`."""
    var cache = InMemoryCache()
    var handler = GraphQL17Alpha9Handler()
    var query = cache.transform_document(
        handler.transform_document(
            gql(
                "query HeroNameQuery { hero { id ... @defer { name }"
                " nonNullName } }"
            )
        )
    )
    var request = handler.start_request()
    var result = mark_result(
        cache,
        request,
        query,
        json(
            '{"errors":[{"message":"Cannot return null for non-nullable field'
            ' Hero.nonNullName.","path":["hero","nonNullName"]}],'
            '"data":{"hero":null}}'
        ),
        error_policy=ErrorPolicy.ALL,
    )
    assert_equal(
        text_of(result.result),
        (
            '{"data":{"hero":null},"errors":[{"message":"Cannot return null'
            ' for non-nullable field Hero.nonNullName.","path":["hero",'
            '"nonNullName"]}]}'
        ),
    )
    assert_true(result.data_state == DataState.COMPLETE)
    assert_extract(cache, '{"ROOT_QUERY":{"__typename":"Query","hero":null}}')


def test_error_policy_none_does_not_write() raises:
    """A result with errors and `errorPolicy: "none"` is not written."""
    var cache = InMemoryCache()
    var handler = GraphQL17Alpha9Handler()
    var query = gql("{ hero { id } }")
    var request = handler.start_request()
    var result = mark_result(
        cache,
        request,
        query,
        json('{"errors":[{"message":"bad"}],"data":{"hero":null}}'),
    )
    assert_true(result.data_state == DataState.COMPLETE)
    assert_extract(cache, "{}")
    var empty = mark_result(
        cache,
        request,
        query,
        json('{"data":null}'),
        cache_write_behavior=CacheWriteBehavior.FORBID,
    )
    assert_true(empty.data_state == DataState.EMPTY)
    assert_extract(cache, "{}")


def _check_stream_merge(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The merge function of "provides streamFieldInfo to merge functions":
    it checks the arguments of each of the three upstream calls."""
    ref values = options.cache[].values
    var count = values.length(incoming)
    var info = options.stream_field_info.value()
    if count == 1:
        assert_true(existing == NO_VALUE)
        assert_true(info == StreamFieldInfo(True, False))
    elif count == 2:
        assert_equal(values.stringify(existing), '[{"__ref":"Friend:1"}]')
        assert_true(info == StreamFieldInfo(False, False))
    else:
        assert_equal(
            values.stringify(existing),
            '[{"__ref":"Friend:1"},{"__ref":"Friend:2"}]',
        )
        assert_true(info == StreamFieldInfo(False, True))
    assert_true(options.extensions == NO_VALUE)
    return incoming


def test_provides_stream_field_info_to_merge_functions() raises:
    """Provides streamFieldInfo to merge functions."""
    var config = InMemoryCacheConfig()
    var policy = FieldPolicy()
    policy.merge = Merge(_check_stream_merge)
    add_field(config, "Query", "friendList", policy^)
    var cache = InMemoryCache(config)
    var handler = GraphQL17Alpha9Handler()
    var query = cache.transform_document(
        gql("query { friendList @stream(initialCount: 1) { id name } }")
    )
    var request = handler.start_request()
    var first = mark_result(
        cache,
        request,
        query,
        json(
            '{"data":{"friendList":[{"__typename":"Friend","id":"1",'
            '"name":"Luke"}]},"pending":[{"id":"0","path":["friendList"]}],'
            '"hasNext":true}'
        ),
    )
    assert_true(first.data_state == DataState.COMPLETE)
    _ = mark_result(
        cache,
        request,
        query,
        json(
            '{"incremental":[{"items":[{"__typename":"Friend","id":"2",'
            '"name":"Han"}],"id":"0"}],"hasNext":true}'
        ),
    )
    var last = mark_result(
        cache,
        request,
        query,
        json(
            '{"incremental":[{"items":[{"__typename":"Friend","id":"3",'
            '"name":"Leia"}],"id":"0"}],"completed":[{"id":"0"}],'
            '"hasNext":false}'
        ),
    )
    assert_equal(
        text_of(last.result),
        (
            '{"data":{"friendList":[{"__typename":"Friend","id":"1","name":'
            '"Luke"},{"__typename":"Friend","id":"2","name":"Han"},'
            '{"__typename":"Friend","id":"3","name":"Leia"}]},"extensions":{}}'
        ),
    )


def _stream_info(is_last: Bool, position: Int) -> StreamInfo:
    """Return stream information with an entry for `friendList`."""
    var key = String()
    path_key_append(key, "friendList", False)
    var info = StreamInfo()
    info.set(
        key,
        StreamInfoEntry(
            StreamFieldInfo(False, is_last), StreamArrayState(False, position)
        ),
    )
    return info^


def test_default_stream_field_merge_keeps_items_until_the_last_chunk() raises:
    """A `@stream` array without a merge function keeps the existing items
    after the incoming ones until the last payload, as upstream
    `defaultStreamFieldMergeFn`."""
    var cache = InMemoryCache()
    var query = gql("query { friendList @stream(initialCount: 1) { id name } }")
    var plain = gql("query { friendList { id name } }")
    _ = cache.write_query(
        plain,
        json(
            '{"friendList":[{"__typename":"Friend","id":"1","name":"Luke"},'
            '{"__typename":"Friend","id":"2","name":"Han"},'
            '{"__typename":"Friend","id":"3","name":"Leia"}]}'
        ),
    )
    _ = cache.write_query(
        query,
        json('{"friendList":[{"__typename":"Friend","id":"4","name":"Rey"}]}'),
        stream_info=_stream_info(False, 1),
    )
    assert_extract(
        cache,
        (
            '{"Friend:1":{"__typename":"Friend","id":"1","name":"Luke"},'
            '"Friend:2":{"__typename":"Friend","id":"2","name":"Han"},'
            '"Friend:3":{"__typename":"Friend","id":"3","name":"Leia"},'
            '"Friend:4":{"__typename":"Friend","id":"4","name":"Rey"},'
            '"ROOT_QUERY":{"__typename":"Query","friendList":[{"__ref":'
            '"Friend:4"},{"__ref":"Friend:2"},{"__ref":"Friend:3"}]}}'
        ),
    )
    _ = cache.write_query(
        query,
        json(
            '{"friendList":[{"__typename":"Friend","id":"4","name":"Rey"},'
            '{"__typename":"Friend","id":"5","name":"Finn"}]}'
        ),
        overwrite=True,
        stream_info=_stream_info(True, 2),
    )
    var result = cache.read_query(plain)
    assert_equal(
        text_of(result.value()),
        (
            '{"friendList":[{"__typename":"Friend","id":"4","name":"Rey"},'
            '{"__typename":"Friend","id":"5","name":"Finn"}]}'
        ),
    )


def test_stream_field_with_if_false_replaces_the_array() raises:
    """A field whose `@stream` has `if: false`, or a false variable, is not
    a stream field: the incoming array replaces the existing one."""
    var cache = InMemoryCache()
    var plain = gql("query { list { id } }")
    _ = cache.write_query(
        plain,
        json(
            '{"list":[{"__typename":"T","id":"1"},{"__typename":"T","id":"2"}]}'
        ),
    )
    _ = cache.write_query(
        gql("query { list @stream(if: false) { id } }"),
        json('{"list":[{"__typename":"T","id":"3"}]}'),
        stream_info=_stream_info(False, 1),
    )
    assert_equal(
        text_of(cache.read_query(plain).value()),
        '{"list":[{"__typename":"T","id":"3"}]}',
    )
    _ = cache.write_query(
        gql(
            'query Q($on: Boolean, $other: Int) { list @stream(label: "l",'
            " if: $on) { id } }"
        ),
        json('{"list":[{"__typename":"T","id":"4"}]}'),
        json('{"on":false}'),
        stream_info=_stream_info(False, 1),
    )
    assert_equal(
        text_of(cache.read_query(plain).value()),
        '{"list":[{"__typename":"T","id":"4"}]}',
    )


def _check_user_name(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The merge function of "provides extensions to merge functions"."""
    ref values = options.cache[].values
    var name = String(values.text(incoming))
    if name == "Dahivat Pandya":
        assert_true(existing == NO_VALUE)
        assert_equal(values.stringify(options.extensions), '{"keepAlive":true}')
    elif name == "Vyacheslav Kim":
        assert_equal(values.stringify(existing), '"Dahivat Pandya"')
        assert_equal(
            values.stringify(options.extensions), '{"keepAlive":false}'
        )
    else:
        assert_equal(values.stringify(existing), '"Vyacheslav Kim"')
        assert_true(options.extensions == NO_VALUE)
    assert_false(Bool(options.stream_field_info))
    return incoming


comptime _SUBSCRIPTION = """
    subscription UserInfo($name: String) {
      user(name: $name) {
        name
      }
    }
"""


def test_provides_extensions_to_merge_functions() raises:
    """Provides extensions to merge functions (subscriptions)."""
    var config = InMemoryCacheConfig()
    var policy = FieldPolicy()
    policy.merge = Merge(_check_user_name)
    add_field(config, "User", "name", policy^)
    var cache = InMemoryCache(config)
    var subscription = cache.transform_document(gql(_SUBSCRIPTION))
    var variables = json('{"name":"Changping Chen"}')
    var first = mark_subscription_result(
        cache,
        subscription,
        json(
            '{"data":{"user":{"__typename":"User","name":"Dahivat Pandya"}},'
            '"extensions":{"keepAlive":true}}'
        ),
        variables,
    )
    assert_equal(
        text_of(first),
        (
            '{"data":{"user":{"__typename":"User","name":"Dahivat Pandya"}},'
            '"extensions":{"keepAlive":true}}'
        ),
    )
    var mapped = subscribe_result(first)
    assert_equal(
        text_of(mapped.value().extensions.value()), '{"keepAlive":true}'
    )
    _ = mark_subscription_result(
        cache,
        subscription,
        json(
            '{"data":{"user":{"__typename":"User","name":"Vyacheslav Kim"}},'
            '"extensions":{"keepAlive":false}}'
        ),
        variables,
    )
    var last = mark_subscription_result(
        cache,
        subscription,
        json('{"data":{"user":{"__typename":"User","name":"Changping Chen"}}}'),
        variables,
    )
    assert_equal(
        text_of(last),
        '{"data":{"user":{"__typename":"User","name":"Changping Chen"}}}',
    )
    assert_false(Bool(subscribe_result(last).value().extensions))


def test_should_not_cache_subscription_data_with_no_cache() raises:
    """Should not cache subscription data if a `no-cache` fetch policy is
    used."""
    var cache = InMemoryCache()
    var subscription = cache.transform_document(gql(_SUBSCRIPTION))
    var result = mark_subscription_result(
        cache,
        subscription,
        json('{"data":{"user":{"__typename":"User","name":"Amanda Liu"}}}'),
        cache_write_behavior=CacheWriteBehavior.FORBID,
    )
    assert_extract(cache, "{}")
    assert_equal(
        text_of(subscribe_result(result).value().data.value()),
        '{"user":{"__typename":"User","name":"Amanda Liu"}}',
    )


def test_emits_an_error_if_the_result_has_graphql_errors() raises:
    """Emits an error if the result has GraphQL errors: the data is not
    written, and with `errorPolicy: "none"` the result has no data."""
    var cache = InMemoryCache()
    var subscription = cache.transform_document(gql(_SUBSCRIPTION))
    var raw = json(
        '{"data":{"user":{"__typename":"User","name":"Amanda Liu"}},'
        '"errors":[{"message":"This is an error"}]}'
    )
    var result = mark_subscription_result(cache, subscription, raw)
    assert_extract(cache, "{}")
    var mapped = subscribe_result(result)
    assert_false(Bool(mapped.value().data))
    assert_equal(
        text_of(mapped.value().error.value()),
        '[{"message":"This is an error"}]',
    )
    var ignored = subscribe_result(result, ErrorPolicy.IGNORE)
    assert_false(Bool(ignored.value().error))
    assert_true(Bool(ignored.value().data))
    var all = subscribe_result(result, ErrorPolicy.ALL)
    assert_true(Bool(all.value().error) and Bool(all.value().data))
    assert_false(Bool(subscribe_result(json('{"data":null}'))))
    assert_false(
        Bool(
            subscribe_result(
                json('{"errors":[{"message":"x"}]}'), ErrorPolicy.IGNORE
            )
        )
    )


def test_subscription_result_with_errors_and_policy_all_is_written() raises:
    """With `errorPolicy: "all"`, a result with data and errors is
    written, and the read replaces the data when it is complete."""
    var cache = InMemoryCache()
    var subscription = cache.transform_document(gql(_SUBSCRIPTION))
    var result = mark_subscription_result(
        cache,
        subscription,
        json(
            '{"errors":[{"message":"x"}],"data":{"user":{"__typename":"User",'
            '"name":"Amanda Liu"}}}'
        ),
        error_policy=ErrorPolicy.ALL,
    )
    assert_equal(
        text_of(result),
        (
            '{"errors":[{"message":"x"}],"data":{"user":{"__typename":"User",'
            '"name":"Amanda Liu"}}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_SUBSCRIPTION":{"__typename":"Subscription","user":'
            '{"__typename":"User","name":"Amanda Liu"}}}'
        ),
    )


def test_extensions_are_available_in_merge_functions() raises:
    """Extensions are available in merge functions (`writeQuery`), and are
    undefined when not provided."""
    var config = InMemoryCacheConfig()
    var policy = FieldPolicy()
    policy.merge = Merge(_check_book)
    add_field(config, "Query", "book", policy^)
    var cache = InMemoryCache(config)
    var query = gql("query { book { title } }")
    var data = json('{"book":{"__typename":"Book","title":"Test Book"}}')
    _ = cache.write_query(
        query,
        data,
        extensions=json(
            '{"customField":"customValue","metadata":{"version":1}}'
        ),
    )
    _ = cache.write_query(
        query, json('{"book":{"__typename":"Book","title":"Other"}}')
    )


def _check_book(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The merge function of the `extensions.test.ts` cases."""
    ref values = options.cache[].values
    if existing == NO_VALUE:
        assert_equal(
            values.stringify(options.extensions),
            '{"customField":"customValue","metadata":{"version":1}}',
        )
    else:
        assert_true(options.extensions == NO_VALUE)
    return incoming


def test_the_types_of_options() raises:
    """`ErrorPolicy`, `CacheWriteBehavior` and `DataState` are types with
    `is_valid`."""
    assert_equal(String(ErrorPolicy.ALL), "ErrorPolicy(2)")
    assert_true(ErrorPolicy.ALL.is_valid())
    assert_false(ErrorPolicy(3).is_valid())
    assert_equal(String(CacheWriteBehavior.MERGE), "CacheWriteBehavior(2)")
    assert_true(CacheWriteBehavior.MERGE.is_valid())
    assert_false(CacheWriteBehavior(3).is_valid())
    assert_equal(String(DataState.COMPLETE), "DataState(3)")
    assert_true(DataState.COMPLETE.is_valid())
    assert_false(DataState(4).is_valid())


def test_as_query_and_with_data() raises:
    """`as_query` keeps a document without an operation, and `with_data`
    adds `data` last, or writes `null` for no data."""
    var fragment = gql("fragment F on T { a }")
    assert_equal(len(as_query(fragment).nodes), len(fragment.nodes))
    assert_equal(
        text_of(with_data(json('{"errors":[]}'), None)),
        '{"errors":[],"data":null}',
    )
    assert_equal(
        text_of(with_data(json('{"data":1}'), JsonDocument())), '{"data":null}'
    )


def test_incomplete_subscription_read_keeps_the_result() raises:
    """A read of the subscription that is not complete keeps the data of
    the result."""
    var cache = InMemoryCache()
    var subscription = cache.transform_document(gql(_SUBSCRIPTION))
    var result = mark_subscription_result(
        cache, subscription, json('{"data":{"user":{"__typename":"User"}}}')
    )
    assert_equal(text_of(result), '{"data":{"user":{"__typename":"User"}}}')


def test_subscribe_result_drops_empty_extensions() raises:
    """Extensions that are not an object, or that are empty, are not in
    the subscribe result."""
    var array = subscribe_result(json('{"data":{},"extensions":[1]}'))
    assert_false(Bool(array.value().extensions))
    var empty = subscribe_result(json('{"data":{},"extensions":{}}'))
    assert_false(Bool(empty.value().extensions))


def test_mark_result_with_a_partial_read() raises:
    """A read that is partial keeps the merged result, unless the query
    returns partial data."""
    var cache = InMemoryCache()
    var handler = GraphQL17Alpha9Handler()
    var query = cache.transform_document(gql("{ hero { id name } }"))
    var chunk = json('{"data":{"hero":{"__typename":"Hero","id":"1"}}}')
    var request = handler.start_request()
    var kept = mark_result(cache, request, query, chunk)
    assert_true(kept.data_state == DataState.COMPLETE)
    assert_equal(
        text_of(kept.result), '{"data":{"hero":{"__typename":"Hero","id":"1"}}}'
    )
    var partial = mark_result(
        cache, request, query, chunk, return_partial_data=True
    )
    assert_true(partial.data_state == DataState.PARTIAL)


def _check_extensions_with_stream(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """A merge function of a field that is not a stream, in a write with
    stream information."""
    ref values = options.cache[].values
    assert_equal(values.stringify(options.extensions), '{"a":1}')
    assert_false(Bool(options.stream_field_info))
    return incoming


def test_stream_writes_keep_extensions_for_other_fields() raises:
    """With stream information, a merge function of a field outside the
    streams gets the extensions and no stream information."""
    var config = InMemoryCacheConfig()
    var policy = FieldPolicy()
    policy.merge = Merge(_check_extensions_with_stream)
    add_field(config, "Query", "book", policy^)
    var cache = InMemoryCache(config)
    _ = cache.write_query(
        gql("query { book { title } }"),
        json('{"book":{"__typename":"Book","title":"T"}}'),
        extensions=json('{"a":1}'),
        stream_info=_stream_info(False, 1),
    )


def test_stream_field_detection() raises:
    """`isStreamField`: `@stream` after another directive, an `if` that is
    not a boolean or a variable, and a field without `@stream`."""
    var cache = InMemoryCache()
    var plain = gql("query { friendList { id } other { id } }")
    _ = cache.write_query(
        gql(
            'query { friendList @include(if: true) @stream(if: "x") { id }'
            " other { id } }"
        ),
        json(
            '{"friendList":[{"__typename":"T","id":"1"}],"other":[{"__typename":'
            '"T","id":"2"}]}'
        ),
        stream_info=_stream_info(False, 1),
    )
    assert_equal(
        text_of(cache.read_query(plain).value()),
        (
            '{"friendList":[{"__typename":"T","id":"1"}],"other":[{"__typename"'
            ':"T","id":"2"}]}'
        ),
    )


def test_default_stream_merge_without_stream_field_info() raises:
    """A `@stream` array whose path has no entry merges as a payload that
    is not the last: an incoming array that is longer replaces the items."""
    var cache = InMemoryCache()
    var plain = gql("query { list { id } }")
    _ = cache.write_query(
        plain,
        json(
            '{"list":[{"__typename":"T","id":"1"},{"__typename":"T","id":"2"}]}'
        ),
    )
    var key = String()
    path_key_append(key, "elsewhere", False)
    var info = StreamInfo()
    _ = info.lookup(key)
    _ = cache.write_query(
        gql("query { list @stream { id } }"),
        json(
            '{"list":[{"__typename":"T","id":"3"},{"__typename":"T","id":"4"},'
            '{"__typename":"T","id":"5"}]}'
        ),
        stream_info=info,
    )
    assert_equal(
        text_of(cache.read_query(plain).value()),
        (
            '{"list":[{"__typename":"T","id":"3"},{"__typename":"T","id":"4"},'
            '{"__typename":"T","id":"5"}]}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
