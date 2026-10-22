<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# ScorchQL

`gql_scorchql` is ScorchQL: a federated GraphQL gateway with a subgraph registry and a web explorer. It joins `gql_router`, `gql_router_stream`, `gql_composition`, `gql_ws` and `gql_http`. ScorchQL is original work, and it ports no upstream project. [How to host a gateway](How-to-host-a-gateway) tells you how to run it.

## Modules

| Module | Contents |
| --- | --- |
| `gql_scorchql.registry` | `Registry`, `PublishedSubgraph`, `PublishResult`, `compose_published`, `publish_errors`, `is_valid_subgraph_name`, `is_valid_routing_url`, `write_file_atomic`, `read_file` |
| `gql_scorchql.introspect` | `fetch_subgraph_sdl`, `read_service_sdl`, `SERVICE_QUERY` |
| `gql_scorchql.gateway` | `Gateway`, `GatewayConfig`, `SharedGateway`, `GatewayWsExecutor`, `GatewayWsHandler`, `serve_gateway`, `refresh_registry`, `RefreshOutcome`, `wants_explorer` |
| `gql_scorchql.explorer` | `explorer_page`, `EXPLORER_HTML`, `FAVICON_SVG`, `escape_html`, `script_json` |
| `gql_scorchql.cli` | `parse_cli`, `CliOptions`, `CommandKind`, `SubscriptionMode`, `gateway_config`, `admin_request`, `send_admin`, `USAGE` |

`bin/scorchql.mojo` is the `scorchql` program. `bin/scorchql_demo.mojo` serves two demo subgraphs. `make scorchql` builds both into `dist/`.

## Registry

A registry is a directory that every worker process shares:

| File | Contents |
| --- | --- |
| `subgraphs/<name>.json` | The name, the routing URL, the SDL and the publish time of one subgraph |
| `supergraph.graphql` | The composed supergraph SDL |
| `revision` | A counter that each change increments |

`Registry.publish(name, url, sdl)` composes the new set of subgraphs with `gql_composition`. When composition fails, the registry refuses the publish and changes nothing. When it succeeds, the registry writes the files and increments the revision. A publish with the same URL and SDL changes nothing.

`Registry.remove(name)` composes the other subgraphs. It refuses the removal when they do not compose. A name starts with a letter and has only letters, digits, `_` and `-`. A routing URL starts with `http://`.

Each file is written to a temporary name, then renamed. So a reader never sees part of a file. Two processes that publish at the same time can lose one publish.

## Gateway

`Gateway` is a `gql_http` handler, and `serve_gateway` serves it with `GatewayWsHandler` on one `gql_ws` port. It answers these requests:

| Method and path | Answer |
| --- | --- |
| `GET /` | The explorer |
| `GET` the GraphQL path from a browser, without `query` | The explorer |
| `GET` or `POST` the GraphQL path | The GraphQL response or stream |
| `Upgrade: websocket` on the GraphQL path | `graphql-transport-ws` over WebSocket |
| `GET /health` | `{"status":"pass"}` |
| `GET /scorchql/state` | The mode, the revision, the ports, the subscription mode and the subgraphs |
| `GET /scorchql/supergraph.graphql` | The supergraph SDL |
| `POST /scorchql/plan` | The query plan of `{query, operationName}` |
| `POST /scorchql/publish` | Publish `{name, url, sdl}`; without `sdl`, the gateway reads it from the subgraph |
| `POST /scorchql/remove` | Remove `{name}` |
| `POST /scorchql/refresh` | Read the SDL of each subgraph again, and publish each change |

When `GatewayConfig.publish_token` is set, the last three requests need `Authorization: Bearer <token>`. In static mode, the gateway serves a fixed supergraph, and these three requests answer `409`.

Before each request, at most once every 250 milliseconds, each worker reads the registry revision. When it has changed, the worker builds a new stream hub and router. So a publish reaches every worker without a restart. When the new supergraph cannot be served, the worker keeps the old router and reports the error in `loadError`.

Before the first publish, a GraphQL request answers `503` with the code `NO_SUPERGRAPH`.

### Subscriptions and @defer

The gateway runs operations, subscriptions and streamed `@defer` through `gql_router` and `gql_router_stream`. Clients can stream subscriptions over `graphql-transport-ws` WebSocket, Server-Sent Events (`text/event-stream`), incremental delivery (`multipart/mixed`), or Apollo multipart HTTP (`multipart/mixed;subscriptionSpec=1.0`). Operations with `@defer` stream over `multipart/mixed` or `text/event-stream`.

`--subscriptions` selects how the gateway opens subgraph subscriptions:

- `ws` (the default) uses `graphql-transport-ws` over WebSocket.
- `http` uses HTTP streaming (`text/event-stream` or `multipart/mixed`).
- `off` disables subscriptions and answers `SUBSCRIPTIONS_NOT_SUPPORTED`.

### Transports

The `scorchql` program serves HTTP/1.1, SSE, multipart and RFC 6455 WebSocket with worker processes. With `--tls-cert` and `--tls-key`, it also starts one process for HTTP/2, HTTP/1.1 and RFC 8441 WebSockets over TLS. It starts another process for HTTP/3 and RFC 9220 WebSockets over QUIC. Each answer then has the header `Alt-Svc: h3=":<port>"; ma=86400`.

The library itself does not depend on `gql_tls`. Only the program loads OpenSSL.

## Explorer

The explorer is one HTML page in `EXPLORER_HTML`, with its CSS and JavaScript. It loads nothing from the network. It has four views:

| View | Contents |
| --- | --- |
| Explorer | The documentation with a checkbox per field, the operation editor, variables and headers, the response, and the query plan |
| Schema | Each type of the API schema, with the subgraphs that resolve each field |
| Subgraphs | The published subgraphs, their SDL, and the forms to publish, update and remove a subgraph |
| SDL | The API schema and the supergraph SDL |

A checked field adds the field to the operation. A required argument adds a variable. The editor highlights GraphQL, completes field names with `Ctrl+Space`, and runs the operation with `Ctrl+Enter`.

For a subscription, the **Run** button becomes **Subscribe** and opens a `graphql-transport-ws` WebSocket to the gateway. While the subscription runs, the button shows **Stop** and each event updates the response pane. For an operation with `@defer`, the explorer streams `multipart/mixed` and merges each incremental payload into the response.

The variables and the headers have a JSON mode and a fields mode. Fields mode shows one input for each declared variable, with a control for its type. `Poll` runs a query again at an interval. The response shows its status, its transport, its time and its size.

The explorer reads `/scorchql/state` every 5 seconds. When the revision changes, it reads the schema again.

## Limits

- The gateway does not send client headers to the subgraphs.
- Composition and the router support Apollo Federation 2.
