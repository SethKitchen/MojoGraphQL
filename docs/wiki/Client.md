<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Client

`gql_client` is the normalized cache of a GraphQL client. It is a port of the `InMemoryCache` of Apollo Client 4.3.3 (`ae0dfce`). It writes query results into a store of entities, and reads queries and fragments back. It also merges the payloads of `@defer` and `@stream`, and writes each payload and each subscription result to the cache. It needs only `gql_language` and `gql_json`.

| Module | Contents | Apollo Client source |
| --- | --- | --- |
| `gql_client.cache` | `InMemoryCache`, `InMemoryCacheConfig`, the policy function contexts, `default_data_id_from_object`, `DELETE`, `INVALIDATE` | `inMemoryCache.ts`, `core/cache.ts`, parts of `policies.ts` and `entityStore.ts` |
| `gql_client.policies` | `TypePolicy`, `FieldPolicy`, `KeyFields`, `KeyArgs`, `Merge`, the function types, `Policies` | `policies.ts` |
| `gql_client.write` | `write_to_store` and the merge trees | `writeToStore.ts` |
| `gql_client.read` | `diff_query_against_store`, `DiffResult`, `MissingFieldError` | `readFromStore.ts`, `core/types/common.ts` |
| `gql_client.store` | `EntityStore`, `Entry` | `entityStore.ts` |
| `gql_client.values` | `Values`, `ValueKind`, `Member`, `Interner` | `StoreValue`, `canonicalStringify.ts`, `DeepMerger.ts` |
| `gql_client.helpers` | Store key names, `should_include`, `check_document`, `add_typename_to_document` | `helpers.ts` and `src/utilities` |
| `gql_client.key_extractor` | `KeySpecifier` | `key-extractor.ts` |
| `gql_client.fuzzy` | The patterns of fuzzy `possibleTypes` | `new RegExp(subtype)` |
| `gql_client.incremental` | `GraphQL17Alpha9Handler`, `Defer20220824Handler`, their requests, `StreamInfo`, `merge_at_path`, `add_defer_fragment_labels`, `has_directives` | `src/incremental/handlers/`, `DeepMerger.ts`, `makeStreamInfoTrie.ts`, `addDeferFragmentLabels.ts`, `hasDirectives.ts` |
| `gql_client.query_info` | `mark_result`, `mark_subscription_result`, `subscribe_result`, `ErrorPolicy`, `CacheWriteBehavior`, `DataState` | `src/core/QueryInfo.ts`, `QueryManager.startGraphQLSubscription` |

The package `gql_client_http` reads HTTP responses. It needs `gql_http` and `gql_json`, so a user of the cache alone does not build `gql_http`. See [HTTP responses](#http-responses).

```mojo
from gql_client.cache import InMemoryCache
from gql_json.parser import parse as parse_json
from gql_json.writer import stringify
from gql_language.parser import parse

var cache = InMemoryCache()
var query = parse("{ book(id: 1) { id title author { id name } } }")
_ = cache.write_query(query, parse_json(
    '{"book": {"__typename": "Book", "id": 1, "title": "Beloved",'
    ' "author": {"__typename": "Author", "id": 7, "name": "Toni Morrison"}}}'
))
print(cache.extract())
var result = cache.read_query(query)
print(stringify(result.value(), result.value().root))
```

## InMemoryCache

`InMemoryCache(config)` makes an empty cache. A query is a `Document` of `gql_language`. Data and variables are `JsonDocument`s of `gql_json`, and the value is the root of the document.

| Method | Apollo Client | Result |
| --- | --- | --- |
| `write_query(query, data, variables, id, overwrite)` | `writeQuery` | The id that the data went to |
| `write_fragment(fragment, data, id, fragment_name, variables, overwrite)` | `writeFragment` | The id that the data went to |
| `read_query(query, variables, id, return_partial_data)` | `readQuery` | An `Optional[JsonDocument]`; None is `null` |
| `read_fragment(fragment, id, fragment_name, variables, return_partial_data)` | `readFragment` | An `Optional[JsonDocument]` |
| `diff(query, variables, id, return_partial_data)` | `diff` | A `DiffResult` |
| `identify(object)` | `identify` | An `Optional[String]` |
| `modify(fields, id, all)` | `modify` | Whether a field changed |
| `evict(id, field_name, args)` | `evict` | Whether something was removed |
| `gc()` | `gc` | The removed ids, in store order |
| `retain(id)`, `release(id)` | `retain`, `release` | The number of holds on the id |
| `extract()` | `JSON.stringify(cache.extract())` | The JSON text of the store |
| `restore(data)`, `restore_text(text)` | `restore` | Nothing; the data replaces the store |
| `reset()` | `reset` | Nothing; the store is empty, and the policies stay |
| `transform_document(document)` | `transformDocument` | The document with `__typename` added |

The default `id` of a query is `ROOT_QUERY`. `read_query` and `read_fragment` do not keep partial data by default. `diff` keeps it by default, as upstream does.

`read_fragment` and `write_fragment` take a document of fragment definitions. Give `fragment_name` when the document has more than one fragment. When `id` is empty, `write_fragment` identifies the data, and `read_fragment` reads from `ROOT_QUERY`.

`extract` writes the entities in the order they were added. An id that is an array index comes first, as ECMAScript orders keys. A write retains the id that it writes. `extract` lists the retained ids that are not root ids in `__META.extraRootIds`.

## Errors

Each method raises an `Error` with the message of the upstream invariant. A message shows an object as `stringifyForDisplay(object, 2)`, cut to 1000 bytes.

| Message | When |
| --- | --- |
| `Could not identify object {...}` | A write has no id and the data has no id |
| `Missing field 'name' while extracting keyFields from {...}` | An object lacks a field of its `keyFields` |
| `No fragment named Name` | A spread names a fragment that the document does not have |
| `Must contain a query definition.` | A read of a document without a query operation |
| `Ambiguous GraphQL document: contains 2 operations` | A document with more than one operation |
| `Missing selection set for object of type T returned for query field f` | A read finds a `Reference` in a field without a selection set |
| `Cannot automatically merge arrays` | `merge: true` gets an array |

## DiffResult and MissingFieldError

`DiffResult` has the fields `result: Optional[JsonDocument]`, `complete: Bool` and `missing: Optional[MissingFieldError]`. `MissingFieldError` has the fields `message: String` and `missing: JsonDocument`.

The `missing` document is the tree of the missing fields. Its keys are the result keys, and its leaves are messages. The messages are the upstream messages:

- `Can't find field 'name' on Book:1 object`
- `Can't find field 'name' on object {...}`, for an object that has no id
- `Dangling reference to missing Book:1 object`

`message` is the first message of the tree, depth first.

## InMemoryCacheConfig

| Field | Apollo Client option | Default |
| --- | --- | --- |
| `type_policies: Dict[String, TypePolicy]` | `typePolicies` | No policies |
| `possible_types: Dict[String, List[String]]` | `possibleTypes` | No supertypes |
| `data_id_from_object: Optional[KeyFieldsFunction]` | `dataIdFromObject` | `default_data_id_from_object` |

`default_data_id_from_object` gives `__typename:id`, or else `__typename:_id`. A number or a string goes in as its text, and another value as its JSON. An object of the type of `ROOT_QUERY` is always `ROOT_QUERY`.

A subtype in `possible_types` that is not a plain name is a pattern, such as `.*Entity`. The patterns are the part of ECMAScript `RegExp` that type names need: literal characters, `.`, character classes, `*`, `+`, `?`, `^`, `$` and escapes. Other syntax is refused.

## Type and field policies

| Field of `TypePolicy` | Apollo Client option |
| --- | --- |
| `key_fields: KeyFields` | `keyFields` |
| `merge: Merge` | `merge` |
| `fields: Dict[String, FieldPolicy]` | `fields` |
| `query_type`, `mutation_type`, `subscription_type: Bool` | `queryType`, `mutationType`, `subscriptionType` |

| Field of `FieldPolicy` | Apollo Client option |
| --- | --- |
| `key_args: KeyArgs` | `keyArgs` |
| `read: Optional[FieldReadFunction]` | `read` |
| `merge: Merge` | `merge` |

`KeyFields` and `KeyArgs` take a specifier, a function, or `disabled()`, which is the option `false`. A specifier is the upstream array as JSON text, such as `KeyFields.parse('["isbn", "author", ["name"]]')`. `KeySpecifier.from_paths(["isbn", "author.name"])` gives the same specifier. A `KeyArgs` path can start with `@directive` or `$variable`, as upstream allows.

`Merge(True)` merges objects with `mergeObjects`. `Merge(False)` keeps the incoming value. `Merge(function)` runs a merge function.

The policies of a supertype apply to its subtypes, as upstream applies them.

## Policy functions

A policy function is a Mojo function pointer. A value that it gets or gives is an `Int` index into `cache[].values`. `NO_VALUE`, which is `-1`, is `undefined`.

| Type | Signature |
| --- | --- |
| `FieldReadFunction` | `def(existing: Int, mut options: FieldFunctionOptions) raises thin -> Int` |
| `FieldMergeFunction` | `def(existing: Int, incoming: Int, mut options: FieldFunctionOptions) raises thin -> Int` |
| `KeyFieldsFunction` | `def(mut context: KeyFieldsContext) raises thin -> String` |
| `KeyArgsFunction` | `def(args: Int, mut context: KeyArgsContext) raises thin -> String` |
| `Modifier` | `def(value: Int, mut details: ModifierDetails) raises thin -> Int` |

`FieldFunctionOptions` has `args`, `field_name`, `store_field_name`, `variables` and `cache`. Its methods are `read_field`, `read_field_from`, `to_reference`, `is_reference`, `can_read` and `merge_objects`. `ModifierDetails` has the same readers, and `to_reference_object` for an object to normalize.

A `Modifier` returns the new value, `DELETE` to remove the field, or `INVALIDATE` to keep it. An empty string from a key function is `undefined`.

```mojo
from gql_client.cache import FieldFunctionOptions
from gql_client.values import NO_VALUE

def concat(existing: Int, incoming: Int, mut options: FieldFunctionOptions) raises -> Int:
    ref values = options.cache[].values
    var items = values.array_items(existing)
    items.extend(Span(values.array_items(incoming)))
    return values.add_array(items)
```

## Values

`Values` is the arena of the cache. A value does not change after it is added.

| Method | Result |
| --- | --- |
| `kind(value)` | The `ValueKind`: `NULL`, `FALSE`, `TRUE`, `UNDEFINED`, `NUMBER`, `STRING`, `REFERENCE`, `ARRAY` or `OBJECT` |
| `text(value)` | The text of a number or a string |
| `get(object, key)`, `length(value)`, `item(array, index)` | The parts of a value |
| `ref_text(reference)` | The entity id of a `Reference` |
| `add_string`, `add_int`, `add_float`, `add_bool`, `add_array`, `add_object`, `add_reference` | A new value |
| `equal(a, b)`, `merge(a, b)` | `@wry/equality` `equal` and the `DeepMerger` merge |
| `stringify(value)`, `canonical_stringify(value)` | `JSON.stringify` and `canonicalStringify` |
| `from_json(document, node)`, `to_json(document, value)` | A copy from or to a `JsonDocument` |

A value that nothing uses stays in the arena until the next compaction. The cache compacts the arena when it is more than twice its live size. The compaction comes at the end of a write, a `modify`, an `evict`, a `gc` or a `restore`.

## Incremental delivery

A request of an incremental handler merges the payloads of `@defer` and `@stream` into one result. `GraphQL17Alpha9Handler` reads the format of graphql-js 17, which `gql_execution.incremental` writes: `pending`, `incremental`, `completed` and `hasNext`. `Defer20220824Handler` reads the older format, where each incremental item has a `path`.

```mojo
from gql_client.cache import InMemoryCache
from gql_client.incremental import GraphQL17Alpha9Handler
from gql_client.query_info import mark_result
from gql_json.parser import parse as parse_json
from gql_language.parser import parse

var cache = InMemoryCache()
var handler = GraphQL17Alpha9Handler()
var query = cache.transform_document(
    handler.transform_document(parse("{ hero { id ... @defer { name } } }"))
)
var request = handler.start_request()
var first = mark_result(cache, request, query, parse_json(
    '{"data":{"hero":{"__typename":"Hero","id":"1"}},'
    '"pending":[{"id":"0","path":["hero"]}],"hasNext":true}'
))
# first.data_state is DataState.STREAMING
var last = mark_result(cache, request, query, parse_json(
    '{"incremental":[{"id":"0","data":{"name":"Luke"}}],'
    '"completed":[{"id":"0"}],"hasNext":false}'
))
# last.result is {"data":{"hero":{"__typename":"Hero","id":"1","name":"Luke"}}}
```

| Member of a handler | Apollo Client | Use |
| --- | --- | --- |
| `start_request()` | `startRequest` | A new `IncrementalRequest` or `DeferRequest` |
| `is_incremental_result(result)` | `isIncrementalResult` | True when the result has `hasNext` |
| `extract_errors(result)` | `extractErrors` | The array of the errors, or None |
| `prepare_accept(document, accept)` | `prepareRequest` | The `accept` values, with the multipart type first for `@defer` or `@stream` |
| `transform_document(document)` | `documentTransform` | `GraphQL17Alpha9Handler` only: a label on each `@defer` |

`request.handle(cache_data, chunk)` merges one payload and returns a `FormattedExecutionResult`. Its members are indices into `request.acc.values`. `request.stringify(result)` gives the JSON text, `request.to_json(result)` a `JsonDocument`, and `request.data_json(result)` the data alone. `cache_data` is None for `undefined`: the request then goes on from its own data. `request.has_next` is the `hasNext` of the last payload.

An `IncrementalRequest` has `stream_info`, the `@stream` arrays by path, and `pending_with_info()`, as `getPendingWithInfo`. When a request has a stream, `result.has_stream_info` is True, and `extensions` is `{}` at least, as upstream shows the symbol key.

`mark_result(cache, request, query, chunk, variables, error_policy, cache_write_behavior, return_partial_data)` does the cache part of `QueryInfo.markQueryResult`:

1. It reads the query from the cache with partial data, and gives the read to `handle` as `cache_data`.
2. It writes the merged result with `write_query`, with the `extensions` of the result and the stream information.
3. It reads the query again. A complete read, or a read while deferred data is to come, replaces the data.

A result with errors goes to the cache only with `ErrorPolicy.IGNORE` or `ErrorPolicy.ALL`, and only when it has data. `CacheWriteBehavior.FORBID` does no write, and `OVERWRITE` writes with `overwrite`.

`write_query` has two more arguments. Merge functions get `extensions` as `options.extensions`. With `stream_info`, a `@stream` array that has no merge function merges with `default_stream_field_merge`, and a merge function of a `@stream` field gets `options.stream_field_info`. `options.existing_data` is the existing value, also with `overwrite`.

## Subscriptions

`mark_subscription_result(cache, document, result, variables, error_policy, cache_write_behavior)` writes one result of a subscription to `ROOT_SUBSCRIPTION`, as `QueryInfo.markSubscriptionResult`. It reads the subscription back as a query. A complete read replaces the data of the result.

`subscribe_result(raw, error_policy)` gives the `SubscribeResult` of one result, as `QueryManager.startGraphQLSubscription`: `data`, `error` (the array of the GraphQL errors) and `extensions`. With `ErrorPolicy.NONE`, a result with errors has no data. With `ErrorPolicy.IGNORE`, it has no error. A result with no data and no error gives None.

## HTTP responses

`gql_client_http.response` is a port of `src/link/http/parseAndCheckHttpResponse.ts`.

`MultipartBodyReader(content_type, status)` reads a `multipart/mixed` response as its bytes arrive. `feed(bytes)` returns the results of the parts that the bytes complete, as `readMultipartBody`. `finish()` raises `premature end of multipart body` when the close delimiter did not arrive. The `MultipartDecoder` of `gql_http` reads the parts. `boundary_from_content_type` reads the boundary with the regular expression of upstream, and gives `-` when no parameter matches.

A part must have no content type, or a JSON content type. A result that is an empty object is skipped. A result of the multipart subscription protocol, `{"payload": ...}`, gives its payload, and its `errors` are `MultipartResult.protocol_errors`. `{"payload": null}` ends the reading.

`parse_and_check_http_response(operation_name, status, content_type, body_text)` parses a JSON response. A status of 300 or more raises `Response not successful: Received status code N`, except for `application/graphql-response+json`. A result that is not an array, and has no `data` and no `errors`, raises `Server response was malformed for query 'name'.`

## Differences from Apollo Client

- **No result cache.** A read builds a new result. Watches, broadcasts, `batch`, `performTransaction` and `resultCaching` are not ported.
- **No optimistic layers.** `recordOptimisticTransaction` and `removeOptimistic` are not ported.
- **Not ported.** Custom scalars, the fragment registry, reactive variables, `updateQuery`, `updateFragment` and the `storage` of policy functions.
- **No client.** `ApolloClient`, `QueryManager`, `ObservableQuery`, the links and the network are not ported. `query_info` ports only the cache writes of a result. Apollo Link has the network; `gql_client_http` ports only its response parsing.
- **No incremental reads.** `cache.diff` does not prune the pending `@defer` boundaries (`deferInfo`) or cut the pending `@stream` arrays (`StreamArrayState.truncate`) of Apollo Client 4.3. A result whose deferred data is to come has the data state `STREAMING` and the read with partial data. The memo of the last stream merge (`streamInfo.previous`) is not ported, so a merge function runs for each write.
- **No data masking.** `maskOperation`, `maskFragment` and `@unmask` are not ported. They change the data that a client gives to a component, not the data that the cache stores.
- **Results as values.** A handler result is a set of value indices, and the stream information is `request.stream_info`, not a `WeakRef` under a symbol key. A hole of a sparse `@stream` array becomes `null` in `data_json`, so a cache write keeps no hole.
- **HTTP errors.** `ServerError`, `ServerParseError` and `CombinedProtocolErrors` are not classes: they are `Error`s with the upstream messages, and a parse error has the message of `gql_json`.
- **No warnings.** The development warnings of upstream, such as the data loss warning, are not printed.
- **Options.** The methods take their options as arguments. `extract` gives JSON text. A key function returns a `String`, not a new specifier.
- **Numbers.** A number keeps the text that `JSON.stringify` writes for it. Two numbers are equal when their texts are equal.
- **Malformed input.** An `@connection` key that is not a string goes in the store field name as JSON. A forbidden alias in a fragment document gives the usual error. Upstream fails with a `TypeError` in both cases.

## Tests

The tests are in `tests/gql_client/`. They port these upstream files of `src/cache/inmemory/__tests__/`: `writeToStore.ts`, `readFromStore.ts`, `cache.ts`, `policies.ts`, `entityStore.ts`, `roundtrip.ts`, `diffAgainstStore.ts`, `key-extractor.ts`, `helpers.ts` and `fragmentMatcher.ts`. Each module docstring lists the upstream cases that it does not port, and the reason.

`test_extract_exact.mojo` compares `extract()` and read results with the bytes that Apollo Client 4.3.3 gives in Node.js.

`test_incremental_graphql17_defer.mojo`, `test_incremental_graphql17_stream.mojo`, `test_incremental_defer20220824_defer.mojo` and `test_incremental_defer20220824_stream.mojo` port the four files of `src/incremental/handlers/__tests__/`. Each case has the payloads and the results of the upstream test. They were recorded in Node.js with graphql 17.0.0-alpha.9 or alpha.2, the versions of the upstream tests. `test_query_info.mojo` ports the cache part of the upstream cases that run `ApolloClient`, and of `cache.writeQuery/extensions.test.ts`. `test_incremental_paths.mojo` tests the helpers and the malformed payloads.

The tests of `gql_client_http` are in `tests/gql_client_http/`. They port `src/link/http/__tests__/responseIterator.ts` and `parseAndCheckHttpResponse.ts`.

## Benchmarks

`bench/gql_client/client.mojo` and `bench/baselines/js-client/bench.mjs` run the same workloads on `bench/fixtures/client-items-1000.json`. The fixture has 1000 `Item` entities, each with an `Author` entity and an embedded object. Apollo Client 4.3.3 publishes no runtime benchmark of its cache, so the workloads are the project's own.

`bench/gql_client/incremental.mojo` runs `client/merge-deferred-chunks-100`: a new `GraphQL17Alpha9Handler` request, then `handle` of 101 payloads. The first payload has 100 items, each with a pending `@defer`. Each next payload delivers one item. The payloads are parsed in setup, as the link parses them before the handler. The baseline runs the same workload.

The baseline runs the production build of Apollo Client, with `node --conditions=production`. Its read workloads use `resultCaching: false`, so that each read reads the store. The [Benchmarks](Benchmarks) page tells how the project measures.
