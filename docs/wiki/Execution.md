<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Execution

`gql_execution` runs a GraphQL operation against a schema and gives the result as JSON. It is a port of graphql-js 16.14.2 `src/execution`, `subscribe` included, `src/type/introspection.ts`, `getIntrospectionQuery`, `introspectionFromSchema` and `buildClientSchema`. It needs `gql_language`, `gql_schema`, `gql_json` and `gql_stream`.

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
- `field_timing` is an addition for the inline trace plugin of `gql_server`. When it is set, execution records a `FieldTiming` for each resolved field in `ExecutionResult.field_timings`. A timing has the path, the field name, the type, the parent type and the times of the resolver. The fields are those that Apollo Server wraps: the fields of the object types whose names do not start with `__`. Meta fields and introspection fields have no timing. When `field_timing` is False, execution does not record anything.

## Tests

The tests are in `tests/gql_execution/`. They port the graphql-js tests of `src/execution/__tests__`, `subscribe-test.ts` included, `src/type/__tests__/introspection-test.ts`, `getIntrospectionQuery-test.ts`, `introspectionFromSchema-test.ts`, `buildClientSchema-test.ts`, `coerceInputValue-test.ts`, `valueFromAST-test.ts` and `valueFromASTUntyped-test.ts`. Each module docstring lists the upstream cases that are not ported, and why.

Many expected results come from graphql-js 16.14.2 itself, run in Node.js with the same SDL, document and values. That includes each upstream execution of `variables-test.ts` and `introspection-test.ts`, and the serialization of more than 400 values.

## Benchmarks

`bench/gql_execution/graphql_js.mojo` runs three graphql-js benchmarks:

- `introspectionFromSchema-benchmark.js`, "Execute Introspection Query", is `graphql-js/execute-introspection-query`. It executes the introspection query against the GitHub schema. apollo-compiler `introspection::partial_execute` runs the same workload.
- `repeated-fields-benchmark.js`, "Many repeated fields", is `graphql-js/repeated-fields-parse-execute`. Upstream also validates the document, and validation is not in this package. Thus the workload and its graphql-js baseline time `parse` and `executeSync` only.
- `buildClientSchema-benchmark.js`, "Build Schema from Introspection", is `graphql-js/build-client-schema`. It builds the GitHub schema from its introspection result.

`bench/gql_execution/subscribe.mojo` runs `stream/subscribe-publish-100`. It subscribes to an operation, then publishes 100 events to a `PubSub` and reads the 100 responses. The baseline in `bench/baselines/js-stream` runs graphql-js `subscribe` with a graphql-subscriptions `PubSub` in Node.js.

The [Benchmarks](Benchmarks) page tells how the project measures and gives the numbers.
