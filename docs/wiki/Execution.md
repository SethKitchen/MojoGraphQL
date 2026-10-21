<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Execution

`gql_execution` runs a GraphQL operation against a schema and gives the result as JSON. It is a port of graphql-js 16.14.2 `src/execution`, `subscribe` included, `src/type/introspection.ts`, `getIntrospectionQuery`, `introspectionFromSchema` and `buildClientSchema`. Incremental delivery, `@defer` and `@stream`, is a port of graphql-js 17.0.2 (`71606d73`). It needs `gql_language`, `gql_schema`, `gql_json` and `gql_stream`.

```mojo
from gql_execution.execute import ExecutionArgs, ResolveInfo, execute
from gql_execution.value import Values
from gql_language.parser import parse
from gql_schema.build import build_schema


def hello(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("world")


def main() raises:
    var schema = build_schema("type Query { hello: String }")
    var args = ExecutionArgs()
    args.resolvers.field("Query", "hello", hello)
    var result = execute(schema, parse("{ hello }"), args)
    print(result.to_json())  # {"data":{"hello":"world"}}
```

Execution does not validate the document. Validate it first with `gql_validation`, as a server does.

## Functions

| Function | graphql-js | Result |
| --- | --- | --- |
| `execute(schema, document, args)` | `executeSync(args)` | `ExecutionResult` |
| `execute(schema, document)` | `executeSync({ schema, document })` | `ExecutionResult` |
| `execute_sync(schema, document, args)` | `executeSync(args)` | `ExecutionResult` |
| `subscribe(schema, document, args)` | `subscribe(args)` | `Subscription` |
| `experimental_execute_incrementally(schema, document, args)` | `experimentalExecuteIncrementally(args)` (17.0.2) | `ExperimentalIncrementalExecutionResults` |
| `create_source_event_stream(schema, document, args)` | `createSourceEventStream(args)` | `SourceEventStream` |
| `get_variable_values(schema, document, operation, values, inputs, max_errors)` | `getVariableValues` | `CoercedVariables` |
| `get_argument_values(schema, owner, definition, document, node, values, variables)` | `getArgumentValues` | An object of `Values` |
| `get_directive_values(schema, directive, document, node, values, variables)` | `getDirectiveValues` | An object, or `UNDEFINED` |
| `coerce_input_value(schema, values, value, type)` | `coerceInputValue` | A value |
| `value_from_ast(schema, document, node, type, values, variables)` | `valueFromAST` | A value, or `UNDEFINED` |
| `value_from_ast_untyped(document, node, values, variables)` | `valueFromASTUntyped` | A value |
| `get_introspection_query(options)` | `getIntrospectionQuery` | `String` |
| `introspection_from_schema(schema, options, assume_valid)` | `introspectionFromSchema` | `JsonDocument` |
| `build_client_schema(document, introspection, assume_valid)` | `buildClientSchema` | `Schema` |

`execute` raises an `Error` in two cases, as graphql-js throws. The first case is a schema that is not valid. The second case is variable values that are not an object.

## Values

Mojo has no dynamic objects, so `gql_execution.value` keeps the JavaScript values of an execution in one arena. A `Values` arena holds the root value, the context value, the variable values, the arguments and each value that a resolver returns. A value is an `Int` index into the arena. `UNDEFINED`, which is `-1`, is the JavaScript `undefined`.

| `ValueKind` | Holds |
| --- | --- |
| `UNDEFINED`, `NULL` | Nothing |
| `BOOLEAN`, `NUMBER`, `STRING` | A scalar; a number is a `Float64`, as in JavaScript |
| `LIST`, `OBJECT` | Items, or members with keys in insertion order |
| `HANDLE` | A host object: a `tag`, an `id` and two extra numbers |
| `ERROR` | A JavaScript `Error` that a resolver returns, with its message |

A handle names data that is not in the arena, such as a row of a table. Give each kind of host object a tag of zero or more, and give each object an id. Introspection uses the negative tags.

`Values.add_json(document, node)` copies a JSON value into the arena. Use it for the variables of a request. A value has at most one parent. To put a value into a second container, use `Values.copy(value)`.

`inspect(values, value)` writes a value as graphql-js `inspect` does. The error messages use it.

## Resolvers

A resolver is a Mojo function that `Resolvers` registers for a type and a field. It reads its source and its arguments in the arena, and it returns a value of the arena:

```mojo
def resolve(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int
```

| Method of `Resolvers` | graphql-js | Use |
| --- | --- | --- |
| `field(type_name, field_name, resolve)` | `resolve` of a field | Resolve one field |
| `type_resolver(type_name, resolve)` | `resolveType` | Name the object type of a value of an interface or a union |
| `is_type_of(type_name, check)` | `isTypeOf` | Check that a value is of an object type |
| `field_resolver(resolve)` | `ExecutionArgs.fieldResolver` | Resolve each field that has no resolver |
| `default_type_resolver(resolve)` | `ExecutionArgs.typeResolver` | Resolve each abstract type that has no type resolver |

A field with no resolver uses `default_field_resolver`, which is graphql-js `defaultFieldResolver`. It returns the property of the source object that has the name of the field. An abstract type with no type resolver uses graphql-js `defaultTypeResolver`. It reads the `__typename` property, then it calls the `isTypeOf` of each possible type.

A type resolver returns the name of the object type as a string value. A resolver raises an `Error` to fail its field. The message of the `Error` becomes the message of the field error. A resolver can also return an error value, as a JavaScript resolver can return an `Error`.

`ResolveInfo` holds `field_name`, `field`, `field_nodes`, `return_type`, `parent_type`, `path`, `operation`, `root_value`, `context_value` and `variable_values`.

## ExecutionArgs

| Field | graphql-js | Default |
| --- | --- | --- |
| `values` | The JavaScript values | An empty arena |
| `root_value` | `rootValue` | `UNDEFINED` |
| `context_value` | `contextValue` | `UNDEFINED` |
| `variable_values` | `variableValues` | `UNDEFINED` |
| `operation_name` | `operationName` | None |
| `resolvers` | `resolve`, `resolveType`, `isTypeOf`, `fieldResolver`, `typeResolver` | No resolvers |
| `max_coercion_errors` | `options.maxCoercionErrors` | 50 |
| `assume_valid_schema` | A schema built with `assumeValid` | False |
| `field_timing` | The Apollo Server `willResolveField` hook | False |

The arena stays in `args.values` after execution. A resolver can change values there, as a mutation resolver changes its data.

## Results

`ExecutionResult.data` is a `JsonDocument`. Its root is the data object, `null`, or `NO_NODE` when the result has no `data` key. `ExecutionResult.errors` holds each `GraphQLError`, with its locations and its response path. `to_json()` gives the text of graphql-js `JSON.stringify(result)`: the keys, their order and the errors are the same.

Execution writes the result directly into the `JsonDocument`. A field that fails becomes `null`, and the error goes up to the nearest field that can be `null`, as in graphql-js.

## Subscriptions

`gql_execution.subscribe` ports graphql-js `subscribe.ts`. `subscribe` calls the `subscribe` function of the root field, and gets the source event stream. Each event of that stream becomes the root value of one execution, as `mapAsyncIterator` maps it. See [Stream](Stream) for the streams.

```mojo
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.subscribe import subscribe
from gql_execution.value import Values
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub
from gql_stream.stream import AnyStream
from gql_stream.waker import Waker


def main() raises:
    var schema = build_schema(
        "type Query { a: String } type Subscription { greeting: String }"
    )
    var pubsub = PubSub()
    var args = ExecutionArgs()
    var root = args.values.add_object()
    var source = AnyStream(pubsub.subscribe("GREETING"))
    args.values.add_member(root, "greeting", args.values.add_stream(source^))
    args.root_value = root
    var subscription = subscribe(schema, parse("subscription { greeting }"), args^)
    var responses = subscription.take_stream()
    pubsub.publish("GREETING", Event.parse('{"greeting":"Hello"}'))
    var waker = Waker.noop()
    print(responses.poll_next(waker).value().to_json())
    # {"data":{"greeting":"Hello"}}
```

A `subscribe` function is a `FieldResolver`. Set it with `Resolvers.subscribe(type_name, field_name, resolve)`. It returns a value that `Values.add_stream` made. A field with no `subscribe` function uses `Resolvers.subscribe_field_resolver`, which is `default_field_resolver` by default. That resolver returns the property of the root value, as in the example.

`subscribe` returns a `Subscription`. It holds a `ResponseStream`, or an `ExecutionResult` with errors and no data. `take_stream()` takes the stream. `to_json()` gives the JSON of the result. `subscribe` raises in the cases where graphql-js rejects:

- The schema is not valid, or the variable values are not an object.
- The subscription field does not return a stream: `Subscription field must return Async Iterable. Received: ...`.

A `ResponseStream` is an `EventStream`. Each event is the JSON of an `ExecutionResult`, with the keys of `ExecutionResult.to_json()`. A field error is in the `errors` of that event, and the stream continues. An error of the source stream ends the stream with `ERROR`.

The execution of an event uses the arena of the subscription. The values of the event are dropped after it, unless a resolver links one of them into an older value.

`create_source_event_stream` returns a `SourceEventStream`. It holds the source event stream, or the result with the errors.

## Incremental delivery

`gql_execution.incremental` executes an operation with `@defer` and `@stream`. It is a port of graphql-js 17.0.2 `experimentalExecuteIncrementally`, with its `IncrementalExecutor`, `IncrementalPublisher`, `WorkQueue` and `buildExecutionPlan`. The payloads have the JSON of graphql-js 17 and of the incremental delivery RFC: `pending`, `incremental`, `completed` and `hasNext`.

```mojo
from gql_execution.execute import ExecutionArgs
from gql_execution.incremental import experimental_execute_incrementally
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_stream.waker import Waker


def main() raises:
    var schema = build_schema("type Hero { id: ID name: String } type Query { hero: Hero }")
    var args = ExecutionArgs()
    var root = args.values.add_object()
    var hero = args.values.add_object()
    args.values.add_member(hero, "id", args.values.add_string("1"))
    args.values.add_member(hero, "name", args.values.add_string("Luke"))
    args.values.add_member(root, "hero", hero)
    args.root_value = root
    var results = experimental_execute_incrementally(
        schema, parse("{ hero { id ... @defer { name } } }"), args^
    )
    print(results.to_json())
    # {"data":{"hero":{"id":"1"}},"pending":[{"id":"0","path":["hero"]}],"hasNext":true}
    var stream = results.take_subsequent_results()
    var waker = Waker.noop()
    print(stream.poll_next(waker).value().to_json())
    # {"hasNext":false,"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}]}
```

`experimental_execute_incrementally(schema, document, args)` returns an `ExperimentalIncrementalExecutionResults`:

| Member | graphql-js | Use |
| --- | --- | --- |
| `is_incremental()` | `'initialResult' in result` | True when payloads follow |
| `result` | An `ExecutionResult` | The single result, when there is nothing to deliver later |
| `initial_result` | `initialResult` | An `InitialIncrementalExecutionResult`: `data`, `errors`, `pending` and `hasNext` |
| `take_subsequent_results()` | `subsequentResults` | The `SubsequentResultStream` |
| `to_json()` | `JSON.stringify` | The JSON of the single result or of the initial result |

The result is single when the operation has no deferred fragment and no stream to deliver, as in graphql-js. A deferred fragment that has no field of its own is not delivered.

A `SubsequentResultStream` is a `gql_stream` `EventStream`. Each event is the JSON of one `SubsequentIncrementalExecutionResult`. After the payload with `"hasNext":false`, the stream is `DONE`. `poll_payload(waker)` gives the payload as a struct, with `pending`, `incremental`, `completed`, `has_next` and `to_json()`. `is_done()` tells when no payload follows. `close()` ends the stream and closes the event streams of `@stream`.

The schema does not have to define `@defer` and `@stream`. Execution reads them with the graphql-js 17 definitions:

```graphql
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT

directive @stream(initialCount: Int! = 0, if: Boolean! = true, label: String) on FIELD
```

Validation refuses an unknown directive. Thus a server must add these definitions to its schema, and it can turn on the [`@defer` and `@stream` rules](Validation).

### Ticks

graphql-js gives the work of one turn of its event loop as one payload. Execution here is synchronous, so a poll runs one tick:

- The first tick executes the deferred fragments of the initial result. A child fragment that its parent releases executes in the same tick.
- A stream that starts in a tick gives its first items in the next tick. One tick gives at most 100 items of a stream, the capacity of the graphql-js stream queue.
- An item that fails a stream ends the batch of the stream. The failure comes in the next tick, after the items before it.
- A tick with no event gives no payload. A poll returns `PENDING` when only event streams remain and no item is ready. Each event stream keeps the waker.

With resolvers that do not return promises, graphql-js 17 gives the same payloads. The tests compare each payload with graphql-js 17.0.2.

### Abort and early execution

An abort stops the subsequent results. Set `ExecutionArgs.abort_signal` to the signal of an `AbortController` from `gql_execution.abort`:

```mojo
var controller = AbortController()
args.abort_signal = controller.signal()
var results = experimental_execute_incrementally(schema, document, args^)
var stream = results.take_subsequent_results()
controller.abort()
# The next poll is ERROR "This operation was aborted", and then DONE.
```

- A signal that aborted before the execution makes `experimental_execute_incrementally` raise the reason.
- An abort after the initial result closes the event streams of `@stream`. The next poll gives the reason one time: `poll_next` returns `ERROR`, and `poll_payload` raises. Each later poll is `DONE`.
- `controller.abort(reason)` sets the message. A second abort changes nothing.
- `SubsequentResultStream.abort(reason)` aborts the stream with no signal.
- An abort after the last payload changes nothing.

`ExecutionArgs.enable_early_execution` is graphql-js `enableEarlyExecution`. The deferred fragments of the initial result execute before `experimental_execute_incrementally` returns, not at the first poll. The payloads do not change.

### Streams

`@stream` streams a list, or an event stream that `Values.add_stream` made. An event stream is the Mojo form of an async iterable, as for subscriptions. Each event of the stream is one item: a JSON value.

- Before `initialCount`, execution polls the event stream. An item that is not ready starts the stream at that index, so the initial result can have fewer items.
- After the stream starts, each tick takes the items that are ready.
- An `ERROR` of the event stream fails the stream, with the message of the error.
- A list field whose resolver returns an event stream, with no `@stream`, must have each item ready. Otherwise the field fails: `The event stream of field "Query.items" has no item ready; use @stream to stream it.`

## Introspection

The meta fields `__typename`, `__schema` and `__type` and the fields of the introspection types use their own resolvers, as in graphql-js. They read the arenas of the `Schema` directly. They write the introspection result into the response without making arena values.

`get_introspection_query(options)` gives the text of graphql-js `getIntrospectionQuery`, character for character. `IntrospectionOptions` holds `descriptions`, `specified_by_url`, `directive_is_repeatable`, `schema_description`, `input_value_deprecation`, `experimental_directive_deprecation`, `one_of` and `type_depth`. The defaults are the graphql-js defaults.

`introspection_from_schema(schema, options)` executes that query and returns its data. Its default options are `IntrospectionOptions.all()`, which turns on each option, as graphql-js does. To turn one option off, start from `IntrospectionOptions.all()`.

## Client schemas

`build_client_schema(document, introspection, assume_valid)` builds a `Schema` from the result of an introspection query, such as the response of a server. `introspection` is the `data` value of the result. The function raises an `Error` with the graphql-js message when the result is not complete.

The function writes the SDL of the result and builds the schema from it, with no SDL validation. The specified scalars and the introspection types are the built-in types, as in graphql-js. A client schema has no resolvers.

These things differ from graphql-js `buildClientSchema`:

- A client schema always has the specified directives, as each `gql_schema` schema does.
- A directive with no locations raises an `Error`, because SDL cannot write it.
- When a result has more than one problem, the first error can differ, because graphql-js reads some parts of the result later.

## Differences from graphql-js

- Execution is synchronous. There are no promises, so `execute` is `executeSync`. A subscription operation executes as graphql-js `execute` executes it.
- `subscribe` returns at once, not a promise. Its response stream is a pull-based `EventStream`, not an `AsyncGenerator`, and it has no `throw()`.
- A `subscribe` function cannot be asynchronous. It must return a stream that `Values.add_stream` made.
- `subscribe` validates the schema one time. Each event executes with `assume_valid_schema`.
- The meta field `__typename` as the root field of a subscription is "not defined". `SingleFieldSubscriptionsRule` refuses such a document, so only a document that is not valid meets it.
- The positional arguments of graphql-js 15 are not ported.
- A resolver is a Mojo function, not a JavaScript function. It raises an `Error` with a message, and it cannot raise a `GraphQLError` with extensions.
- A value is a JSON-like value, a handle or an error. There are no functions, classes, iterables other than arrays, `valueOf` or `toJSON`. A handle has no properties.
- A custom scalar always behaves as a scalar built from SDL. `serialize` and `parseValue` are the identity, and `parseLiteral` is `valueFromASTUntyped`. An enum value is its name.
- `execute` raises the `assertValidSchema` error unless `assume_valid_schema` is set. graphql-js keeps the result of schema validation on the schema. A Mojo schema does not, so validate a schema one time and set the flag.
- graphql-js `CollectedErrors` drops an error under a response path that is already `null`. Only a promise that settles late can cause that, so this port has no such step.
- An error of execution has no source excerpt, so `String(error)` gives only the message. The JSON of a response has no excerpt in graphql-js either.
- A default value that is not valid for its type gives a field error when execution uses it. graphql-js `buildSchema` coerces each default value when it builds the schema, and it can raise there.
- Incremental delivery is a port of graphql-js 17.0.2, not of 16.14.2, because graphql-js 16 has no `@defer` and no `@stream`. `execute` ignores both directives, as graphql-js 16 does.
- `experimental_execute_incrementally` returns at once, and the subsequent results are a pull-based `EventStream`, not an `AsyncGenerator`. `close()` is `return()`. There is no `throw()`.
- A deferred fragment executes when it is released, or before the initial result returns with `enable_early_execution`. A nested fragment executes in the tick that releases it, with or without the flag.
- Execution reads the abort signal before the root fields and at each poll, not during a tick. An abort cannot stop a resolver, because the resolvers are synchronous. The reason is a message, not any value.
- `legacyExecuteIncrementally`, the graphql-js 17 form of the older payload format, is not ported.
- A list item of `@stream` that comes from an event stream, and is not ready before `initialCount`, starts the stream early. graphql-js waits for it.
- The arena of an incremental execution stays with the `SubsequentResultStream` until the stream is dropped, because the deferred fields read it.
- `field_timing` records no timing in an incremental execution.
- `field_timing` is an addition for the inline trace plugin of `gql_server`. When it is set, execution records a `FieldTiming` for each resolved field in `ExecutionResult.field_timings`. A timing has the path, the field name, the type, the parent type and the times of the resolver. The fields are those that Apollo Server wraps: the fields of the object types whose names do not start with `__`. Meta fields and introspection fields have no timing. When `field_timing` is False, execution does not record anything.

## Tests

The tests are in `tests/gql_execution/`. They port the graphql-js tests of `src/execution/__tests__`, `subscribe-test.ts` included, `src/type/__tests__/introspection-test.ts`, `getIntrospectionQuery-test.ts`, `introspectionFromSchema-test.ts`, `buildClientSchema-test.ts`, `coerceInputValue-test.ts`, `valueFromAST-test.ts` and `valueFromASTUntyped-test.ts`. Each module docstring lists the upstream cases that are not ported, and why.

`test_defer.mojo` and `test_stream.mojo` port graphql-js 17.0.2 `src/execution/incremental/__tests__/defer-test.ts` and `stream-test.ts`. `test_incremental_streams.mojo` tests the rules of `IncrementalPublisher.ts` and `WorkQueue.ts`, the event streams and the API. Each case uses a synchronous root value. A promise becomes its value, and an async iterable becomes an event stream. A resolver that throws becomes a property that `throwing_resolver` raises.

`test_incremental_cancel.mojo` ports the upstream cases of the abort signal, `return()` and early execution. Its `ProbeStream` counts the polls and the closes, as the upstream spies on `next()` and `return()`.

The expected payloads are the output of graphql-js 17.0.2, run in Node.js on the same root value. The module docstrings list the upstream cases that are not ported, and why.

Many expected results come from graphql-js 16.14.2 itself, run in Node.js with the same SDL, document and values. That includes each upstream execution of `variables-test.ts` and `introspection-test.ts`, and the serialization of more than 400 values.

## Benchmarks

`bench/gql_execution/graphql_js.mojo` runs three graphql-js benchmarks:

- `introspectionFromSchema-benchmark.js`, "Execute Introspection Query", is `graphql-js/execute-introspection-query`. It executes the introspection query against the GitHub schema. apollo-compiler `introspection::partial_execute` runs the same workload.
- `repeated-fields-benchmark.js`, "Many repeated fields", is `graphql-js/repeated-fields-parse-execute`. Upstream also validates the document, and validation is not in this package. Thus the workload and its graphql-js baseline time `parse` and `executeSync` only.
- `buildClientSchema-benchmark.js`, "Build Schema from Introspection", is `graphql-js/build-client-schema`. It builds the GitHub schema from its introspection result.

`bench/gql_execution/subscribe.mojo` runs `stream/subscribe-publish-100`. It subscribes to an operation, then publishes 100 events to a `PubSub` and reads the 100 responses. The baseline in `bench/baselines/js-stream` runs graphql-js `subscribe` with a graphql-subscriptions `PubSub` in Node.js.

`bench/gql_execution/incremental.mojo` runs two workloads of incremental delivery. The baseline in `bench/baselines/js-incremental` runs graphql-js 17.0.2 `experimentalExecuteIncrementally` in Node.js with the same workload:

- `incremental/defer-100` executes `{ friends { id ... @defer { name } } }` on a list of 100 objects, and reads each payload.
- `incremental/stream-1000` executes `{ friends @stream(initialCount: 10) { id name } }` on a list of 1000 objects, and reads each payload.

The [Benchmarks](Benchmarks) page tells how the project measures and gives the numbers.
