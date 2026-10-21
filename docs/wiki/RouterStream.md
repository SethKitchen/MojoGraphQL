<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# RouterStream

`gql_router_stream` adds subscriptions and streamed `@defer` to `gql_router`. It ports the streaming parts of Hive Router `1a29df9`. A user who needs no streams builds `gql_router` alone, without `gql_ws` and this package. It runs on Linux only.

| Module | Contents |
| --- | --- |
| `gql_router_stream.config` | `SubscriptionsConfig`, `SubscriptionProtocol`, `HeadersSource`, `subscriptions_config_from_json` |
| `gql_router_stream.negotiate` | `ResponseMode`, `SingleContentType`, `StreamContentType`, `parse_accept`, `negotiate` |
| `gql_router_stream.encode` | `StreamFormat`, `HEARTBEAT_MS` |
| `gql_router_stream.subgraph_parse` | The SSE and multipart parsers of subgraph streams |
| `gql_router_stream.subgraph_ws` | `WsPool`, `websocket_url`, `CONNECTION_CLOSED` |
| `gql_router_stream.subgraph_http` | `HttpSubscription`, `StreamError` |
| `gql_router_stream.subscription` | `StreamHub`, `RouterSubscription`, `open_subscription`, `event_poll` |
| `gql_router_stream.defer` | `plan_defer`, `DeferredResponse`, `has_defer` |
| `gql_router_stream.http` | `answer_request`, `StreamAnswer` |
| `gql_router_stream.server` | `RouterStreamHandler`, `RouterWsExecutor`, `RouterWsHandler`, `serve_router`, `router_server_config` |

## How to serve subscriptions through the router

This procedure starts a router that streams subscriptions to clients. You need the `gql_router`, `gql_router_stream` and `gql_ws` packages.

1. Read the supergraph into a `RouterSchema`.
2. Make a transport for the subgraph fetches, such as `HttpTransport`.
3. Read the streaming configuration with `subscriptions_config_from_json`.
4. Make a `StreamHub` with the router and the configuration, in an `ArcPointer`.
5. Call `serve_router` with the hub and a `gql_ws` `ServerConfig`.
6. Call `run` on the server.

```mojo
from std.memory import ArcPointer

from gql_router.exec_http import HttpTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router_stream.config import subscriptions_config_from_json
from gql_router_stream.server import serve_router
from gql_router_stream.subscription import StreamHub
from gql_ws.server import ServerConfig


def main() raises:
    var schema = RouterSchema(open("supergraph.graphql", "r").read())
    var transport = HttpTransport(schema.subgraph_names, schema.subgraph_urls)
    var config = subscriptions_config_from_json(
        '{"subscriptions":{"enabled":true},"websocket":{"enabled":true}}'
    )
    var hub = ArcPointer(StreamHub(Router(schema^, transport^), config^))
    var server = serve_router(hub, ServerConfig())
    server.run()
```

To test the router, send a `POST` to `/graphql` with `Accept: text/event-stream` and a subscription. The response is one `next` event for each subgraph event, and then `complete`. A `graphql-transport-ws` client can also connect to `/graphql`.

## Configuration

`subscriptions_config_from_json` reads the JSON form of the upstream YAML. An unknown field is an error, as upstream.

| Field | Meaning |
| --- | --- |
| `subscriptions.enabled` | Allow subscriptions. Without it, a subscription gets `SUBSCRIPTIONS_NOT_SUPPORTED`. |
| `subscriptions.websocket.all` | Open every subgraph subscription over WebSocket, with an optional `path`. |
| `subscriptions.websocket.subgraphs` | Open the subscriptions of the named subgraphs over WebSocket. |
| `subscriptions.callback` | Read, but not ported: a subscription to a callback subgraph fails. |
| `websocket.enabled` and `websocket.path` | Accept `graphql-transport-ws` clients, on `path` or on the GraphQL path. |
| `traffic_shaping.all.pool_idle_timeout` | How long an idle subgraph WebSocket stays open. |
| `traffic_shaping.all.websocket.reuse_connections` | Whether subgraph subscriptions share one WebSocket. |

A subgraph without a WebSocket setting gets HTTP streaming: `multipart/mixed` or `text/event-stream`, as the subgraph answers.

## Responses to clients

The `Accept` header picks the response mode, as upstream `RequestAccepts::negotiate`.

- **SSE:** `text/event-stream`. Each result is a `next` event; the end is `complete`.
- **Incremental delivery:** `multipart/mixed`, with the boundary `-`.
- **Apollo multipart HTTP:** `multipart/mixed;subscriptionSpec=1.0`, with the boundary `graphql`. Each part is `{"payload":...}`.
- **WebSocket:** `graphql-transport-ws`, from `gql_ws`.

A quiet SSE or Apollo multipart stream gets a heartbeat after `HEARTBEAT_MS`, 10 seconds. A client that accepts only a stream gets its errors in the stream, with status 200, as upstream.

## Subscriptions

`open_subscription` sends the subscription fetch to its subgraph. For each subgraph event, `RouterSubscription` runs the rest of the plan, such as the entity fetches, and projects the event. This is the step of upstream `execute_query_plan` for each event. A failure of the subgraph stream or of an event is one last response with the error, and then the stream ends.

`StreamHub` holds the router, the configuration and the subgraph WebSocket pool. One hub serves every client of a server, on one thread. The server loop polls the subgraph sockets with the client sockets.

## Streamed @defer

Hive Router `1a29df9` has no `@defer`: its planner never makes a `Defer` node. So streamed `@defer` is the design of this package. `plan_defer` makes two documents from the operation:

- **The primary document** has `__typename` in place of each deferred fragment.
- **The full document** has each fragment without its `@defer`.

The router runs the primary document and sends the initial payload at once, with a `pending` entry for each deferred object. Then it runs the full document, and sends one subsequent payload with the deferred fields and `completed`. The payload format is the one of graphql-js 17.0.2. Over WebSocket, an operation with `@defer` is one result.

## Differences from upstream

- **Threads.** The router runs on one thread. A subscription request and the head of a subgraph HTTP response are read with a wait.
- **Deduplication.** Equal client subscriptions do not share one subgraph subscription, and there is no broadcast buffer.
- **Callback protocol.** The HTTP callback protocol is not ported.
- **Headers.** The router forwards no headers, so the WebSocket headers of `connection_init` and of `extensions` are not forwarded.
- **@defer.** The deferred fragments of one request come in one subsequent payload. A nested `@defer` comes with its parent.
- **Configuration.** The configuration is JSON, not YAML. `listen` and the expressions of `public_url` are not read.

## Tests

The tests are in `tests/gql_router_stream/`, with the subscription plan tests in `tests/gql_router/test_subscription_plan.mojo`. The end-to-end suites port the cases of upstream `e2e/src/subscriptions.rs`, `websocket.rs` and `websocket_pool.rs`. They run Mojo subgraphs and the router in child processes, and a client in the test.

## Benchmarks

`bench/gql_router/subscription.mojo` has the workload `hive-router/subscription-event`: one event of `subscription { reviewAdded { id body product { upc name } } }` on upstream `e2e/supergraph.graphql`. The router reads the `reviews` event, fetches the `product` entity from `products`, and projects the response. The subgraphs answer in the same process. The baseline in `bench/baselines/rust-router` runs the same step of upstream: the body of the stream of `execute_query_plan`.

| Workload | Mojo | Hive Router |
| --- | --- | --- |
| `hive-router/subscription-event`, ns | 2,975 | 3,388 |

Streamed `@defer` has no benchmark, because Hive Router `1a29df9` has no `@defer` to compare with. The numbers come from one run of `tools/bench.mojo --check` for `gql_router` on one machine. They change from machine to machine. The [Benchmarks](Benchmarks) page tells how the project measures speed.
