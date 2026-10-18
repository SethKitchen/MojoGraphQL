<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Server

`gql_server` is a GraphQL server. It is a port of Apollo Server 5.5.1 (`0c22029`): the request pipeline, the HTTP handling and the standalone server. It needs `gql_language`, `gql_json`, `gql_schema`, `gql_validation`, `gql_execution` and `gql_http`.

| Module | Contents | Apollo Server source |
| --- | --- | --- |
| `gql_server.server` | `ApolloServer`, `ApolloServerOptions`, `ServerPhase`, `default_context` | `ApolloServer.ts` |
| `gql_server.request_pipeline` | `process_graphql_request`, the persisted queries and the document store | `requestPipeline.ts` |
| `gql_server.run_http_query` | The HTTP request: GET and POST, batches, CSRF prevention, `search_params` | `runHttpQuery.ts`, `httpBatching.ts`, `preventCsrf.ts` |
| `gql_server.standalone` | `start_standalone_server`, `StandaloneHandler`, `request_headers` | `standalone/index.ts`, `cors`, `body-parser` |
| `gql_server.plugin` | `ServerPlugin`, `NoPlugin`, `PluginPair` | The plugin types |
| `gql_server.errors`, `error_normalize` | `ServerError`, the error codes, `formatError` | `errors/index.ts`, `errorNormalize.ts` |
| `gql_server.cache_policy` | `CachePolicy`, `CacheHint`, the `cache-control` field | `cachePolicy.ts`, `plugin/cacheControl` |
| `gql_server.inline_trace` | `InlineTracePlugin`, `InlineTraceOptions`, `schema_is_subgraph` | `plugin/inlineTrace`, `plugin/schemaIsSubgraph.ts` |
| `gql_server.trace_tree_builder` | `TraceTreeBuilder`, `SendErrorsOptions` | `plugin/traceTreeBuilder.ts` |
| `gql_server.usage_reporting_protobuf`, `base64` | The `Trace` protobuf message and its encoding, and base64 | `usage-reporting-protobuf/src/reports.proto` |
| `gql_server.negotiator` | `preferred_media_type`, `mime_essence`, `parse_float` | `negotiator`, `whatwg-mimetype`, `content-type` |
| `gql_server.lru`, `sha256` | The in-memory cache, and SHA-256 | `@apollo/utils.keyvaluecache` |
| `gql_server.http_types`, `types` | `HeaderMap`, the HTTP request and response, `GraphQLRequest` | `utils/HeaderMap.ts`, `externalTypes` |

```mojo
from gql_execution.execute import ResolveInfo, Resolvers
from gql_execution.value import Values
from gql_server.plugin import NoPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.standalone import start_standalone_server

def hello(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("world")

def main() raises:
    var resolvers = Resolvers()
    resolvers.field("Query", "hello", hello)
    var server = ApolloServer.from_type_defs(
        "type Query { hello: String }", resolvers^, ApolloServerOptions(),
        NoPlugin(),
    )
    var running = start_standalone_server(server^)
    print(running.url)
```

## ApolloServer

`ApolloServer.from_type_defs(type_defs, resolvers, options, plugin)` builds the schema from SDL. Call `start` before you send requests.

| Method | Upstream |
| --- | --- |
| `start()`, `stop()` | `start`, `stop` |
| `execute_operation(request)` | `executeOperation` |
| `execute_http_graphql_request(request, context)` | `executeHTTPGraphQLRequest` |

`ApolloServerOptions` has the upstream options with snake case names, such as `introspection`, `persisted_queries`, `csrf_prevention`, `allow_batched_http_requests` and `status400_for_variable_coercion_errors`. `node_env` takes the place of `NODE_ENV`.

## Standalone server

`start_standalone_server(server, config, context)` serves the server over HTTP, as upstream `startStandaloneServer`. The default port is 4000. The result has the `url` and a `stop` method. Each request goes through the CORS headers, the JSON body parser and `execute_http_graphql_request`.

## Plugins

A plugin is a struct that implements `ServerPlugin`. Each hook has a default that does nothing. `PluginPair[A, B]` calls the hooks of `A` and then those of `B`.

## Inline traces

A subgraph server sends federated traces, as Apollo Server does. When a request has the HTTP header `apollo-federation-include-trace: ftv1`, the response gets `extensions.ftv1`. Its value is the base64 of the protocol buffer `Trace` of the request. A gateway or a router reads it.

The trace has the start time, the end time and the duration of the request. Its root node has one child node for each resolved field, and one node for each list item on the path of a field. Each field node has its response name, its type and its parent type. It also has the start and the end of its resolver, in nanoseconds from the start of the trace. An error goes on the node of its path, or on the root when it has no path.

The `inline_trace` option of `ApolloServerOptions` controls the plugin:

| Value | Upstream | Behavior |
| --- | --- | --- |
| `InlineTraceOptions.only_if_subgraph()` | The default plugin | Traces only when the schema has `type _Service { sdl: String }`. This is the default. |
| `InlineTraceOptions()` | `ApolloServerPluginInlineTrace()` | Traces every schema. |
| `None` | `ApolloServerPluginInlineTraceDisabled()` | Never traces. |

`InlineTraceOptions.include_errors` is upstream `includeErrors`. The default masks each error: its message is `<masked>`, with the extension `maskedBy: "ApolloServerPluginInlineTrace"`. `SendErrorsOptions.unmodified()` keeps the errors, and `SendErrorsOptions.with_transform(function)` changes them.

Execution records the times of the resolvers only for a request that asks for a trace. `ExecutionArgs.field_timing` of `gql_execution` turns the recording on. When it is off, execution does not record anything.

## Differences from Apollo Server

- **Execution.** Execution is synchronous. Incremental delivery, `@defer` and the gateway are not ported. A `ServerPlugin` has no `willResolveField` hook. The inline trace plugin gets the field timings of execution after execution.
- **Inline traces.** The inline trace plugin is an option, not a plugin of the type parameter `P`. The server runs its hooks after the hooks of `P`. The trace has no query plan.
- **Plugins.** The plugins are one struct of a type parameter, so `addPlugin` is not ported. The end hooks are methods, not functions that a start hook returns.
- **Cache control.** The `cache-control` field comes from the overall cache policy. No hints come from `@cacheControl` or from resolvers.
- **Errors.** Mojo has no stack traces. `extensions.stacktrace` holds only the first line of the upstream stack.
- **Validation.** `MaxRecursiveSelections` and custom validation rules are not ported. The `NoIntrospection` errors come after the errors of the specified rules.
- **Batches.** The operations of a batch run one after the other.
- **Standalone server.** The server runs in `gql_http` worker processes, and each worker has its own caches. The body must be UTF-8.
- **Not ported.** The landing page, the logger, usage and schema reporting, `stringifyResult`, and custom caches and document stores.

Each module docstring lists its differences in full.

## Tests

The tests are in `tests/gql_server/`. They port `ApolloServer.test.ts`, `runQuery.test.ts`, `documentStore.test.ts`, `standaloneSpecific.test.ts`, `inlineTracePlugin.test.ts`, and the HTTP and federated tracing cases of `packages/integration-testsuite`. The other cases compare each path with Apollo Server 5.5.1 in Node.js. The expected trace encodings come from `@apollo/usage-reporting-protobuf` in Node.js.

## Benchmarks

`bench/gql_server/` runs against Apollo Server 5.5.1 in `bench/baselines/js-server/`. Both use `nodeEnv: 'production'`.

| Workload | What it times |
| --- | --- |
| `server/execute-operation-small` | `execute_operation` of `{ hello }` |
| `server/apq-hit` | The same operation, sent as a persisted query hash |
| `server/execute-ftv1` | `execute_operation` of `{ books { title author } }` with 10 books and the `ftv1` header, with the inline trace plugin |
| `server/http-post-small` | The standalone server under the `gql_http` load generator |
