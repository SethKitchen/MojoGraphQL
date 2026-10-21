<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Sse

`gql_sse` is the GraphQL over Server-Sent Events protocol of graphql-sse 2.6.3. It is a `gql_http` handler that streams results as `text/event-stream`. `gql_sse_execution` connects the protocol to `gql_execution`. Both run on Linux only, and they have no client.

| Module | Contents |
| --- | --- |
| `gql_sse.event` | `StreamEvent`, `StreamMessage`, `EventParser`, `print_message`, `print_ping`, `validate_stream_event`, `parse_stream_data` |
| `gql_sse.handler` | `RequestParams`, `ParseOutcome`, `parse_request`, `Prepared`, `PreparedKind`, `SseExecutor`, `error_json`, and the header and media type constants |
| `gql_sse.server` | `SseHandler`, `PING_MS` |
| `gql_sse.bridge` | `SseBody`, `MultipartBody`, `HeldBodies` |
| `gql_sse.incremental_http` | `IncrementalHandler` |
| `gql_sse_execution.executor` | `GraphQLExecution`, `Roots`, `NoRoot`, `JsonRoot`, `IncrementalStream` |

## How to serve subscriptions over SSE

This procedure starts a server that streams a subscription as SSE events. You need the `gql_sse`, `gql_sse_execution` and `gql_http` packages.

1. Write a `Roots` type. Its `root` method gives the root value of an operation.
2. Put an event stream of `gql_stream` in each subscription field of the root value.
3. Make a `GraphQLExecution` with the schema, the resolvers and the roots.
4. Give the executor to `SseHandler`.
5. Serve the handler with `serve` of `gql_http.server`.

```mojo
from gql_execution.execute import Resolvers
from gql_execution.value import UNDEFINED, Values
from gql_http.server import ServerConfig, serve
from gql_language.ast import Document, OperationType
from gql_schema.build import build_schema
from gql_sse.server import SseHandler
from gql_sse_execution.executor import GraphQLExecution, Roots
from gql_stream.poll import Event
from gql_stream.stream import AnyStream, ListStream


struct Greetings(Roots):
    def root(
        mut self, mut values: Values, document: Document, operation: Int
    ) raises -> Int:
        if document.operation(operation) != OperationType.SUBSCRIPTION:
            return UNDEFINED
        var events = List[Event]()
        events.append(Event.parse('{"greetings":"hi"}'))
        var root = values.add_object()
        var stream = AnyStream(ListStream(events^))
        values.add_member(root, "greetings", values.add_stream(stream^))
        return root


def main() raises:
    var schema = build_schema(
        "type Query { hello: String } type Subscription { greetings: String }"
    )
    var executor = GraphQLExecution(schema^, Resolvers(), Greetings())
    serve(SseHandler(executor^), ServerConfig())
```

To test the server, send a `POST` with `Accept: text/event-stream` and the body `{"query":"subscription { greetings }"}`. The response is one `next` event for each event of the stream, and then one `complete` event.

To stream `@defer` and `@stream` results, set `incremental=True` on `GraphQLExecution`. The schema must then declare the `@defer` and `@stream` directives.

## Distinct connections mode

In this mode, each operation has its own HTTP response. A request with `Accept: text/event-stream` and no stream token gets this mode.

- **Request:** a `GET` with the parameters in the query string, or a `POST` with a JSON body. A mutation over `GET` gets 405 with `allow: POST`.
- **Response:** status 200 with `content-type: text/event-stream; charset=utf-8`. Each result is a `next` event, and the end is a `complete` event.
- **Errors:** a syntax error and an unknown operation get 400 with a JSON error body. A validation error is a `next` event, so the stream reports it.
- **Ping:** a quiet stream gets a comment line each `ping_ms` milliseconds. The value is `PING_MS`, 12000, at first.

## Single connection mode

In this mode, one event stream carries many operations. The client identifies the stream with a token, in the `x-graphql-event-stream-token` header or in the `token` query parameter.

| Request | Result |
| --- | --- |
| `PUT` | Reserves a token: 201 with the token as `text/plain`, or 409 when the token is in use |
| `GET` with `Accept: text/event-stream` and a token | Opens the stream of the token, or 409 when it is open already |
| `POST` with a token and `extensions.operationId` | Adds an operation to the stream: 202, or 409 for a known operation ID |
| `DELETE` with a token and `?operationId=` | Stops one operation |

Each event of an operation in this mode has the operation ID in its data. A token that the server does not know gets 404, `Stream not found`.

## Events

`print_message(out, event, data)` writes one message in the `text/event-stream` format. `StreamEvent` is `NEXT` or `COMPLETE`, a type with `is_valid`.

`EventParser` reads messages from the bytes of a stream, in parts of any size. `feed(chunk, out)` appends each complete `StreamMessage` to `out`. A message without an event, or with an unknown event, raises an error.

## Streamed content

The handlers keep each stream open with `ResponseWriter.hold` of `gql_http`. The server loop then calls `poll_body` for more content.

- **`SseBody`:** writes the events of a `gql_stream` stream as `next` messages and one `complete` message.
- **`MultipartBody`:** writes the events as the parts of a `multipart/mixed` content.
- **`HeldBodies`:** keeps one body for each held response, by connection.
- **`IncrementalHandler`:** answers GraphQL over HTTP with incremental delivery. One result is `application/json`, and a stream of results is `multipart/mixed`.

`IncrementalHandler` uses the format of Apollo Server 4: `multipart/mixed; boundary="-"; deferSpec=20220824`. A client that does not accept `multipart/mixed` gets 406 for a stream of results.

## Execution

`GraphQLExecution[R](schema, resolvers, roots, incremental=False)` is the executor on `gql_execution`. It parses the query, finds the operation and validates it. Then it runs `execute` for a query or a mutation, and `subscribe` for a subscription.

- **Roots:** Mojo has no closures, so a subscription finds its source stream in the root value. `NoRoot` gives no root value, and `JsonRoot` gives a JSON value.
- **Incremental delivery:** with `incremental`, an operation runs as `experimental_execute_incrementally`. The initial payload and each subsequent payload are `next` events.

## Differences from upstream

The package ports graphql-sse 2.6.3 `src/common.ts`, `src/parser.ts` and `src/handler.ts`.

- **Hooks.** The `onSubscribe`, `onOperation`, `onNext` and `onComplete` hooks are one `SseExecutor.prepare`.
- **JSON errors.** A body that is not valid JSON gets the message of `gql_json`, not the message of `JSON.parse`.
- **Connection field.** The server writes the `connection` field itself. The handler does not add `connection: keep-alive`.
- **Failed streams.** A stream that fails ends the connection without `complete`, as an iterator that throws does.
- **Incremental delivery.** graphql-sse runs graphql-js 16, which has no `@defer`. With `incremental`, the operation runs as graphql-js 17 does.
- **Client.** `src/client.ts` and the adapters of `src/use/` are not ported.

## Tests

The tests are in `tests/gql_sse/` and `tests/gql_sse_execution/`. They port the cases of graphql-sse `tests/parser.test.ts` and `tests/handler.test.ts`. The server tests use real sockets on the loopback address.

## Benchmarks

`bench/gql_sse/` has two workloads. The baseline in `bench/baselines/js-sse` runs graphql-sse 2.6.3 on graphql-js 16 with the same workloads.

| Workload | Contents |
| --- | --- |
| `sse/subscribe-1000-next` | The executor reads one `POST` of a subscription, validates it and subscribes. Then `SseBody` writes 1000 `next` events and one `complete`. |
| `sse/parse-1000-next` | An `EventParser` reads a body of 1000 `next` messages and one `complete`, and checks the JSON of each one. |

| Workload | Mojo | Node.js |
| --- | --- | --- |
| `sse/subscribe-1000-next`, ns | 1,307,722 | 3,202,084 |
| `sse/parse-1000-next`, ns | 600,278 | 1,266,116 |

The numbers come from one run of `tools/bench.mojo --check` for `gql_sse` on one machine. They change from machine to machine. The [Benchmarks](Benchmarks) page tells how the project measures speed.
