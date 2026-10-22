<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# MojoGraphQL

MojoGraphQL is a GraphQL library in Mojo. It ports MIT licensed GraphQL projects, and each port must be faster than its upstream. Each part is a separate package, so you use only the parts that you need.

## How-to guides

- [How to install](How-to-install): install the toolchain and run the checks.
- [How to pick packages](How-to-pick-packages): build and use only the packages that you need.
- [How to host a gateway](How-to-host-a-gateway): run the ScorchQL gateway, publish subgraphs, and open its explorer.
- [How to add a feature](How-to-add-a-feature): port a part of an upstream project.
- [How to write documentation](How-to-write-documentation): the writing rules for this wiki.

## Reference

- [Language](Language): the `gql_language` package, which is the lexer, parser and printer.
- [Json](Json): the `gql_json` package, which is the JSON parser, document and writer.
- [Execution](Execution): the `gql_execution` package: execute operations, subscriptions, introspection and `buildClientSchema`.
- [Stream](Stream): the `gql_stream` package, which is the streaming core of subscriptions: event streams, wakers, an epoll event loop, `PubSub` and `withFilter`.
- [Http](Http): the `gql_http` package, which is the HTTP/1.1 server, client and parser.
- [Http2](Http2): the `gql_http2` package, which is HTTP/2 and HPACK: h2c, the h2c upgrade, the HTTP/1.1 fallback, and a `Transport` for TLS.
- [Ws](Ws): the `gql_ws` and `gql_ws_execution` packages: WebSocket servers and clients, and the GraphQL over WebSocket protocol `graphql-transport-ws` for subscriptions.
- [Sse](Sse): the `gql_sse` and `gql_sse_execution` packages: GraphQL over Server-Sent Events as graphql-sse serves it, and incremental delivery as `multipart/mixed`.
- [Tls](Tls): the `gql_tls` package, which is TLS 1.3 and ALPN through the system OpenSSL, and the HTTPS server and client.
- [Https2](Https2): the `gql_https2` package, which is HTTP/2 over TLS with ALPN `h2`: the server, the client with its HTTPS/1.1 fallback, and the TLS `Transport`.
- [Quic](Quic): the `gql_quic` package, which is the QUIC transport.
- [Http3](Http3): the `gql_http3` package, which is HTTP/3 and QPACK over the `gql_quic` transport, `Alt-Svc`, and the client fallback chain.
- [WsHttp2](WsHttp2): the `gql_ws_http2` package, which is WebSockets over HTTP/2: the extended `CONNECT`, an h2c server, a client, and the fallback to HTTP/1.1.
- [WsHttp3](WsHttp3): the `gql_ws_http3` package, which is the protocol part of WebSockets over HTTP/3: the setting, the checks, and a WebSocket on one stream.
- [Validation](Validation): the `gql_validation` package, which checks an executable document against a schema.
- [Normalization](Normalization): the `gql_normalization` package, which normalizes and minifies operations and validates their variables, as graphql-go-tools does.
- [Client](Client): the `gql_client` package, which is the normalized cache of a GraphQL client.
- [Composition](Composition): the `gql_composition` package, which validates Apollo Federation subgraphs.
- [Router](Router): the `gql_router` package, which ports the Hive Router query planner.
- [RouterStream](RouterStream): the `gql_router_stream` package, which adds subscriptions and streamed `@defer` to the router.
- [Subgraph](Subgraph): the `gql_subgraph` package, which builds an executable Apollo Federation subgraph.
- [Server](Server): the `gql_server` package, which is the Apollo Server port and its standalone HTTP server. The `gql_server_ws` package adds subscriptions over WebSocket on the same port.
- [Mcp](Mcp): the `gql_mcp` package, which is the Model Context Protocol server of Apollo MCP Server.
- [ScorchQL](ScorchQL): the `gql_scorchql` package and its `scorchql` program, a federated gateway with a subgraph registry and a web explorer.
- [Seamstress](Seamstress): the `gql_seamstress` package and its `seamstress` program, a port of the local commands of Apollo Rover: `supergraph compose`, `subgraph introspect` and `graph introspect`.
- [Codegen](Codegen): the `gql_codegen` package, which writes Mojo models for operations, as the Apollo Kotlin compiler writes Kotlin.
- [Compiler](Compiler): the `gql_compiler` package, a port of the apollo-compiler schema model from apollo-rs.
- [Compatibility](Compatibility): the result of each check of the Apollo Federation subgraph compatibility suite.
- [Coverage tool](Coverage-tool): what `make coverage` measures, and how.

## Explanation

- [Benchmarks](Benchmarks): how the project measures speed against the upstream libraries.

## Packages

The [README checklist](https://github.com/SethKitchen/MojoGraphQL#features) shows the status of each package.
