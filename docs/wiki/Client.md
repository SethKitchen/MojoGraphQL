<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Client

`gql_client` is the normalized cache of a GraphQL client. It is a port of the `InMemoryCache` of Apollo Client 4.3.3 (`ae0dfce`). It writes query results into a store of entities, and reads queries and fragments back. It needs only `gql_language` and `gql_json`.

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

## Differences from Apollo Client

- **No result cache.** A read builds a new result. Watches, broadcasts, `batch`, `performTransaction` and `resultCaching` are not ported.
- **No optimistic layers.** `recordOptimisticTransaction` and `removeOptimistic` are not ported.
- **Not ported.** Custom scalars, `@defer` and `@stream` merging, the fragment registry, reactive variables, `updateQuery`, `updateFragment` and the `storage` of policy functions.
- **No warnings.** The development warnings of upstream, such as the data loss warning, are not printed.
- **Options.** The methods take their options as arguments. `extract` gives JSON text. A key function returns a `String`, not a new specifier.
- **Numbers.** A number keeps the text that `JSON.stringify` writes for it. Two numbers are equal when their texts are equal.
- **Malformed input.** An `@connection` key that is not a string goes in the store field name as JSON. A forbidden alias in a fragment document gives the usual error. Upstream fails with a `TypeError` in both cases.

## Tests

The tests are in `tests/gql_client/`. They port these upstream files of `src/cache/inmemory/__tests__/`: `writeToStore.ts`, `readFromStore.ts`, `cache.ts`, `policies.ts`, `entityStore.ts`, `roundtrip.ts`, `diffAgainstStore.ts`, `key-extractor.ts`, `helpers.ts` and `fragmentMatcher.ts`. Each module docstring lists the upstream cases that it does not port, and the reason.

`test_extract_exact.mojo` compares `extract()` and read results with the bytes that Apollo Client 4.3.3 gives in Node.js.

## Benchmarks

`bench/gql_client/client.mojo` and `bench/baselines/js-client/bench.mjs` run the same workloads on `bench/fixtures/client-items-1000.json`. The fixture has 1000 `Item` entities, each with an `Author` entity and an embedded object. Apollo Client 4.3.3 publishes no runtime benchmark of its cache, so the workloads are the project's own.

The baseline runs the production build of Apollo Client, with `node --conditions=production`. Its read workloads use `resultCaching: false`, so that each read reads the store. The [Benchmarks](Benchmarks) page tells how the project measures.
