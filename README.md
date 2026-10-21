<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# MojoGraphQL

[![Mojo 1.1.0](https://img.shields.io/badge/Mojo-1.1.0-orange)](https://docs.modular.com/mojo/)
[![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue)](LICENSE)
[![Coverage requirement: 100% line, branch, condition, MC/DC](https://img.shields.io/badge/coverage%20requirement-100%25%20line%20%7C%20branch%20%7C%20condition%20%7C%20MC%2FDC-informational)](https://github.com/SethKitchen/MojoGraphQL/wiki/Coverage-tool)
[![Benchmark requirement: faster than upstream](https://img.shields.io/badge/benchmark%20requirement-faster%20than%20upstream-informational)](https://github.com/SethKitchen/MojoGraphQL/wiki/Benchmarks)

MojoGraphQL is a GraphQL library written from scratch in Mojo. It ports MIT licensed GraphQL projects: graphql-js, apollo-rs, Apollo Server, Apollo Client, Hive Router and others. Each part is a separate Mojo package, so you install only the parts that you need. Each port must be faster than its upstream, and a benchmark proves it.

The project is new. Today it has twenty-four finished packages, and more are in progress.

`gql_language` has the lexer, parser, printer and visitor. `gql_json` reads and writes JSON. `gql_schema` holds the type system. `gql_validation` checks operations, and `gql_execution` runs them. `gql_http` is an HTTP/1.1 server and client. `gql_client` is the Apollo Client normalized cache.

`gql_server` is Apollo Server, and `gql_subgraph` builds Apollo Federation subgraphs. `gql_mcp` is the Apollo MCP Server. `gql_codegen` writes Mojo models for operations, as Apollo Kotlin does. `gql_composition` composes a supergraph, and `seamstress` (`gql_seamstress`) runs the offline Rover commands. `gql_router` plans and runs federated operations over a supergraph. `gql_http2`, `gql_tls` and `gql_http3` serve HTTP/2, HTTPS and HTTP/3, and fall back to what the network supports.

Subscriptions and streams go through the whole stack. `gql_stream` holds the event streams. `gql_execution` runs subscriptions and `@defer`/`@stream`. `gql_ws` and `gql_sse` carry them over WebSocket and Server-Sent Events, and `gql_http` streams `multipart/mixed`. `gql_ws_http2` runs WebSockets over HTTP/2, and falls back to HTTP/1.1.

`gql_server_ws` adds subscriptions to `gql_server`, and `gql_router_stream` adds subscriptions and streamed `@defer` to `gql_router`. A user who needs no streams does not build these packages.

The [feature checklist](#features) shows what is done and what is planned.

## Install

You need Linux on x86-64 or aarch64, macOS on Apple Silicon, or Windows with WSL 2. You also need [uv](https://docs.astral.sh/uv/) to install the Mojo toolchain.

```bash
git clone https://github.com/SethKitchen/MojoGraphQL.git
cd MojoGraphQL
uv venv && uv pip install "mojo==1.1.0"
make check
```

The toolchain is pinned to Mojo `1.1.0` (`8189361e`). Other Mojo versions do not work. See [How to install](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-install) for the details and for Windows.

## Start

Parse a document, read its nodes, and print it again:

```mojo
from gql_language.ast import Role
from gql_language.parser import parse
from gql_language.printer import print_ast


def main() raises:
    var document = parse("query Hero($id: ID!) { hero(id: $id) { name } }")
    print(print_ast(document))
    for definition in document.definitions():
        var selections = document.child(definition, Role.SELECTION_SET)
        for field in document.children(selections, Role.SELECTION):
            print(document.name(field), document.location(field))
```

Run it from the repository root:

```bash
.venv/bin/mojo run -I . hello.mojo
```

A syntax error raises a `GraphQLError`. Print the error to get the graphql-js message and source excerpt. Call `to_json()` to get the GraphQL response error. The [Language reference](https://github.com/SethKitchen/MojoGraphQL/wiki/Language) gives the full API.

## Documentation

The wiki holds the documentation. Its source is in `docs/wiki/`.

- [Home](https://github.com/SethKitchen/MojoGraphQL/wiki/Home): the map of the documentation.
- [How to install](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-install): install the toolchain and run the checks.
- [How to pick packages](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-pick-packages): build and use only the packages that you need.
- [Language](https://github.com/SethKitchen/MojoGraphQL/wiki/Language): the `gql_language` reference.
- [Benchmarks](https://github.com/SethKitchen/MojoGraphQL/wiki/Benchmarks): how the benchmarks measure speed.
- [Coverage tool](https://github.com/SethKitchen/MojoGraphQL/wiki/Coverage-tool): how `make coverage` measures the tests.
- [How to add a feature](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-add-a-feature): port a part of an upstream project.
- [How to write documentation](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-write-documentation): the writing rules.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request.

## Features

Each package ports one upstream project, or one part of it. A checked box is done and tested. An open box is planned.

### gql_language

Port of graphql-js 16.14.2 `src/language`.

- [x] [Source and source locations](https://github.com/SethKitchen/MojoGraphQL/wiki/Language#source-and-sourcelocation)
- [x] [Lexer](https://github.com/SethKitchen/MojoGraphQL/wiki/Language#lexer)
- [x] [Parser for documents, values, types and schema coordinates](https://github.com/SethKitchen/MojoGraphQL/wiki/Language#parse-functions)
- [x] [AST in one arena](https://github.com/SethKitchen/MojoGraphQL/wiki/Language#document)
- [x] [Printer](https://github.com/SethKitchen/MojoGraphQL/wiki/Language#printer)
- [x] [Block strings and quoted strings](https://github.com/SethKitchen/MojoGraphQL/wiki/Language#block-strings-and-quoted-strings)
- [x] [GraphQLError](https://github.com/SethKitchen/MojoGraphQL/wiki/Language#graphqlerror)
- [x] Visitor
- [x] [AST utilities: `stripIgnoredCharacters`, `concatAST`, `separateOperations`, `getOperationAST`, `sortValueNode`](https://github.com/SethKitchen/MojoGraphQL/wiki/Language#ast-utilities)

### gql_schema

Port of graphql-js 16.14.2 `src/type` and the schema utilities of `src/utilities`.

- [x] [Build a schema from SDL, and extend it](https://github.com/SethKitchen/MojoGraphQL/wiki/Schema#build-extend-and-print)
- [x] [Print a schema as SDL](https://github.com/SethKitchen/MojoGraphQL/wiki/Schema#build-extend-and-print)
- [x] [SDL validation](https://github.com/SethKitchen/MojoGraphQL/wiki/Schema#sdl-validation)
- [x] [Schema validation](https://github.com/SethKitchen/MojoGraphQL/wiki/Schema#schema-validation)
- [x] [Type comparators](https://github.com/SethKitchen/MojoGraphQL/wiki/Schema#type-comparators)
- [x] Input value coercion and printing (`valueFromAST`, `astFromValue`)
- [x] [Breaking and dangerous changes (`findBreakingChanges`)](https://github.com/SethKitchen/MojoGraphQL/wiki/Schema#breaking-and-dangerous-changes)
- [x] [Sort a schema (`lexicographicSortSchema`) and `typeFromAST`](https://github.com/SethKitchen/MojoGraphQL/wiki/Schema#schema-utilities)
- [x] Introspection and `buildClientSchema` (in [`gql_execution`](https://github.com/SethKitchen/MojoGraphQL/wiki/Execution))

### Planned packages

- [x] [`gql_json`](https://github.com/SethKitchen/MojoGraphQL/wiki/Json): a strict RFC 8259 parser and a `JSON.stringify` writer, for requests and responses.
- [x] [`gql_validation`](https://github.com/SethKitchen/MojoGraphQL/wiki/Validation): the validation rules of the GraphQL specification.
- [x] [`gql_execution`](https://github.com/SethKitchen/MojoGraphQL/wiki/Execution): execution of operations against a schema, with introspection, subscriptions, and [incremental delivery](https://github.com/SethKitchen/MojoGraphQL/wiki/Execution#incremental-delivery) of `@defer` and `@stream` from graphql-js 17.0.2.
- [x] [`gql_http`](https://github.com/SethKitchen/MojoGraphQL/wiki/Http): an HTTP/1.1 server, client and parser, for GraphQL over HTTP. It streams response bodies, chunked or held, and reads and writes `multipart/mixed`.
- [x] [`gql_sse`](https://github.com/SethKitchen/MojoGraphQL/wiki/Sse): a port of graphql-sse, GraphQL over Server-Sent Events, in the single and distinct connection modes. `gql_sse_execution` runs its operations, subscriptions and `@defer`.
- [x] [`gql_http2`](https://github.com/SethKitchen/MojoGraphQL/wiki/Http2): HTTP/2 and HPACK in Mojo. The server detects the HTTP/2 preface and falls back to HTTP/1.1.
- [x] [`gql_tls`](https://github.com/SethKitchen/MojoGraphQL/wiki/Tls): TLS 1.3 and ALPN through the system OpenSSL, loaded at run time. Only users who pick it need OpenSSL.
- [x] [`gql_https2`](https://github.com/SethKitchen/MojoGraphQL/wiki/Https2): HTTP/2 over TLS. ALPN picks `h2`, and the same connection falls back to HTTPS/1.1.
- [x] [`gql_quic`](https://github.com/SethKitchen/MojoGraphQL/wiki/Quic): a QUIC transport in Mojo, a port of quinn-proto. OpenSSL does only the TLS handshake and the packet protection.
- [x] [`gql_http3`](https://github.com/SethKitchen/MojoGraphQL/wiki/Http3): HTTP/3 and QPACK over `gql_quic`, with `Alt-Svc`. Its client falls back in this order: h3, h2 over TLS, HTTPS/1.1, h2c, HTTP/1.1.
- [x] [`gql_stream`](https://github.com/SethKitchen/MojoGraphQL/wiki/Stream): event streams for subscriptions, polled by an epoll event loop with no thread per stream, and an in-process PubSub.
- [x] [`gql_ws`](https://github.com/SethKitchen/MojoGraphQL/wiki/Ws): WebSocket (RFC 6455) and the `graphql-transport-ws` protocol of graphql-ws, as server and client. `gql_ws_execution` runs its operations and subscriptions.
- [x] [`gql_server`](https://github.com/SethKitchen/MojoGraphQL/wiki/Server): a port of Apollo Server, with the request pipeline, plugins, batching, persisted queries, incremental delivery over `multipart/mixed` and a standalone server. `gql_server_ws` serves its subscriptions over graphql-ws, on the same port.
- [x] [`gql_subgraph`](https://github.com/SethKitchen/MojoGraphQL/wiki/Subgraph): a port of `@apollo/subgraph` and the Apollo Federation subgraph specification, with subscriptions and `@defer`.
- [x] [`gql_composition`](https://github.com/SethKitchen/MojoGraphQL/wiki/Composition): a port of Hive Federation Composition: subgraph validation, supergraph composition, satisfiability and contracts, for federation v1 and v2.0 to v2.15.
- [x] [`gql_router`](https://github.com/SethKitchen/MojoGraphQL/wiki/Router): a port of Hive Router. It plans a federated operation with the [query planner](https://github.com/SethKitchen/MojoGraphQL/wiki/Router#planner), runs the plan against the subgraphs, and serves the supergraph over HTTP. It has the operation cache, [authorization](https://github.com/SethKitchen/MojoGraphQL/wiki/Router#authorization) and [null bubbling](https://github.com/SethKitchen/MojoGraphQL/wiki/Router#null-bubbling).
- [x] [`gql_router_stream`](https://github.com/SethKitchen/MojoGraphQL/wiki/RouterStream): subscriptions and streamed `@defer` through the router. Clients use WebSocket, SSE or multipart HTTP. Subgraphs use WebSocket or HTTP streaming, and each event gets its entities.
- [x] [`gql_client`](https://github.com/SethKitchen/MojoGraphQL/wiki/Client): a port of the Apollo Client normalized cache, `InMemoryCache` with type and field policies. It merges `@defer` and `@stream` payloads and writes each one, and each subscription result, to the cache. `gql_client_http` reads multipart HTTP responses.
- [x] [`gql_codegen`](https://github.com/SethKitchen/MojoGraphQL/wiki/Codegen): code generation in the style of Apollo Kotlin. It writes Mojo models for operations.
- [x] [`gql_compiler`](https://github.com/SethKitchen/MojoGraphQL/wiki/Compiler): a port of apollo-compiler and apollo-parser from apollo-rs. It has the schema and executable document models, the schema printer and validation. Its parser recovers from syntax errors.
- [x] [`gql_normalization`](https://github.com/SethKitchen/MojoGraphQL/wiki/Normalization): a port of the operation tooling of graphql-go-tools: operation normalization, minification and variables validation.
- [x] [`gql_mcp`](https://github.com/SethKitchen/MojoGraphQL/wiki/Mcp): a port of Apollo MCP Server.
- [x] [`gql_seamstress`](https://github.com/SethKitchen/MojoGraphQL/wiki/Seamstress): `seamstress`, a port of the MIT parts of the Rover CLI: `supergraph compose`, `subgraph introspect` and `graph introspect`.
- [x] [Compatibility](https://github.com/SethKitchen/MojoGraphQL/wiki/Compatibility): the Apollo Federation subgraph compatibility suite, as tests of `gql_subgraph`. Every check passes, federated tracing (`ftv1`) included.

The `@apollo/subgraph` port does not use `@apollo/federation-internals`, which is Elastic licensed. It implements the public federation specification instead, with Hive Federation Composition as the MIT reference.

## Pick the parts you need

Each package is a top-level directory and a separate Mojo package. `packages.toml` lists each package and the packages that it imports. `make packages-check` refuses an import that `packages.toml` does not list, and a cycle.

Build one package and the packages that it depends on:

```bash
make package PKG=gql_language
```

The command writes one precompiled `dist/<package>.mojoc` file for the package and for each package in its dependency closure. It builds nothing else. Put the files on the import path of your project with `-I dist`. A precompiled package loads only in the Mojo version that built it. On another Mojo version, copy the source directories of the closure instead. See [How to pick packages](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-pick-packages).

| Package | Status | Depends on | Ports |
| --- | --- | --- | --- |
| `gql_language` | Done | nothing | graphql-js 16.14.2 `src/language` |
| `gql_json` | Done | nothing | RFC 8259; ECMAScript `JSON.stringify` |
| `gql_schema` | Done, except introspection | `gql_language`, `gql_json` | graphql-js `src/type`, `src/utilities` |
| `gql_validation` | Done | `gql_schema` | graphql-js `src/validation` |
| `gql_execution` | Done, with subscriptions and `@defer`/`@stream`; except async resolvers | `gql_schema`, `gql_json`, `gql_stream` | graphql-js 16.14.2 `src/execution`; graphql-js 17.0.2 incremental delivery |
| `gql_http` | Done | nothing | RFC 9110, RFC 9112; GraphQL over HTTP |
| `gql_sse` | Done | `gql_http`, `gql_json`, `gql_stream` | graphql-sse 2.6.3 |
| `gql_sse_execution` | Done | `gql_sse`, `gql_execution`, `gql_validation` | graphql-sse 2.6.3 `handler.ts` |
| `gql_stream` | Done | `gql_json` | graphql-subscriptions PubSub and `withFilter` |
| `gql_ws` | Done | `gql_http`, `gql_stream` | RFC 6455; graphql-ws `graphql-transport-ws`; tungstenite |
| `gql_ws_execution` | Done | `gql_ws`, `gql_execution`, `gql_validation` | graphql-ws `useServer` |
| `gql_ws_http2` | Done | `gql_ws`, `gql_http2` | RFC 8441; h2 0.4.20 extended CONNECT |
| `gql_ws_http3` | Protocol layer only; no QUIC driver yet | `gql_ws_http2`, `gql_http3` | RFC 9220; hyperium/h3 extended CONNECT |
| `gql_http2` | Done | `gql_http` | hyperium/h2 0.4.20; RFC 9113, RFC 7541 |
| `gql_tls` | Done | `gql_http`; system OpenSSL 3 at run time | RFC 8446, RFC 7301 |
| `gql_https2` | Done | `gql_tls`, `gql_http2` | RFC 9113 over TLS; RFC 7301 |
| `gql_quic` | Done | `gql_tls`; system OpenSSL 3.5 at run time | quinn-proto 0.11.19; RFC 9000, RFC 9001, RFC 9002 |
| `gql_http3` | Done | `gql_quic`, `gql_https2`; OpenSSL 3.5 at run time | hyperium/h3; RFC 9114, RFC 9204 |
| `gql_server` | Done | `gql_validation`, `gql_execution`, `gql_http`, `gql_stream` | Apollo Server 5.5.1 |
| `gql_server_ws` | Done, except the subscription callback plugin | `gql_server`, `gql_ws_execution` | Apollo Server 5.5.1 subscriptions with graphql-ws |
| `gql_subgraph` | Done | `gql_execution` | `@apollo/subgraph` 2.14.4 |
| `gql_composition` | Done | `gql_language` | Hive Federation Composition v0.27.0 |
| `gql_router` | Done | `gql_language`, `gql_json`, `gql_http`, `gql_validation` | Hive Router `1a29df9` query planner, executor and pipeline |
| `gql_router_stream` | Done | `gql_router`, `gql_ws`, `gql_stream` | Hive Router `1a29df9` subscriptions; streamed `@defer` |
| `gql_client` | Done, except optimistic layers | `gql_language`, `gql_json` | Apollo Client 4.3.3 `src/cache`, `src/incremental` |
| `gql_client_http` | Done | `gql_http`, `gql_json` | Apollo Client 4.3.3 `parseAndCheckHttpResponse.ts` |
| `gql_codegen` | Done, `operationBased` models only | `gql_validation`, `gql_json` | Apollo Kotlin `apollo-compiler` |
| `gql_compiler` | Done | `gql_language` | apollo-compiler 1.33.0 (apollo-rs) |
| `gql_normalization` | Done | `gql_schema`, `gql_json` | graphql-go-tools v2 `astnormalization`, `astminify`, `variablesvalidation` |
| `gql_mcp` | Done | `gql_validation`, `gql_http` | Apollo MCP Server 2.0.0 |
| `gql_seamstress` | Done, offline commands only | `gql_composition`, `gql_execution`, `gql_http` | Rover 1.0.0, MIT parts |

The dependencies of a planned package can change before it is written. `packages.toml` is the record for each package that exists.

## Benchmarks

Mojo is faster than every baseline on every workload. Each package with a hot path has a benchmark against its upstream library, on the same fixtures. Mojo must be faster than every baseline.

| Package | Workload | Mojo | Fastest other library | Mojo speedup |
| --- | --- | ---: | --- | ---: |
| `gql_language` | Parse the GitHub schema (368 KB of SDL) | 566 µs | graphql-go-tools, 1.61 ms | 2.85x |
| `gql_language` | Parse the introspection query (graphql-js benchmark) | 4.69 µs | graphql-go-tools, 8.41 µs | 1.79x |
| `gql_language` | Print the kitchen sink (graphql-js benchmark) | 2.65 µs | apollo-compiler, 2.73 µs | 1.03x |
| `gql_language` | Strip ignored characters from the GitHub schema | 747 µs | graphql-js, 5.15 ms | 6.9x |
| `gql_json` | Parse the introspection result | 1.21 ms | Node.js `JSON.parse`, 3.85 ms | 3.2x |
| `gql_json` | Stringify a small response | 1.83 µs | astjson, 2.85 µs | 1.56x |
| `gql_http` | Parse a request | 200 ns | httparse, 221 ns | 1.11x |
| `gql_http` | Keep-alive request with a JSON body | 8.95 µs | hyper, 12.7 µs | 1.42x |
| `gql_http` | Stream a chunked response of 16 parts | 10.1 µs | hyper, 25.8 µs | 2.6x |
| `gql_http` | Parse a `multipart/mixed` body of 100 parts | 135 µs | meros, 349 µs | 2.6x |
| `gql_sse` | Subscribe and send 1000 `next` events | 1.31 ms | graphql-sse, 3.20 ms | 2.4x |
| `gql_sse` | Parse 1000 `next` events | 600 µs | graphql-sse, 1.27 ms | 2.1x |
| `gql_http2` | HPACK encode a GraphQL request header block | 815 ns | h2, 1.04 µs | 1.28x |
| `gql_http2` | HPACK decode the same block | 1.02 µs | h2, 2.04 µs | 2.0x |
| `gql_http2` | h2c round trip with a small JSON body | 69.6 µs | hyper and h2, 79.6 µs | 1.14x |
| `gql_tls` | TLS keep-alive request round trip | 82.4 µs | hyper and rustls, 85.4 µs | 1.04x |
| `gql_https2` | h2 over TLS round trip with a small JSON body | 94.1 µs | hyper, h2 and rustls, 113 µs | 1.20x |
| `gql_quic` | Echo 32 bytes on one QUIC stream | 72.3 µs | quinn, 90.3 µs | 1.25x |
| `gql_http3` | QPACK encode a request header block | 702 ns | h3, 2.18 µs | 3.1x |
| `gql_http3` | QPACK decode a request header block | 879 ns | h3, 2.56 µs | 2.9x |
| `gql_http3` | HTTP/3 round trip with a small JSON body | 101 µs | h3 and quinn, 110 µs | 1.09x |
| `gql_schema` | Parse and build the GitHub schema | 1.07 ms | apollo-compiler, 7.85 ms | 7.3x |
| `gql_schema` | Validate the GitHub schema SDL (graphql-js benchmark) | 3.32 ms | graphql-js, 8.01 ms | 2.4x |
| `gql_schema` | Build a schema from a parsed AST, as graphql-js `buildASTSchema` (graphql-js benchmark) | 457 µs | graphql-js, 4.54 ms | 9.9x |
| `gql_compiler` | Build a schema from a parsed AST, as apollo-compiler `Schema::from_ast` | 221 µs | apollo-compiler, 308 µs | 1.39x |
| `gql_compiler` | Build the GitHub query against the GitHub schema | 56.2 µs | apollo-compiler, 85.9 µs | 1.53x |
| `gql_compiler` | Print the GitHub schema, as apollo-compiler `Schema::to_string` | 470 µs | apollo-compiler, 780 µs | 1.66x |
| `gql_compiler` | Validate `many_arguments` (apollo-compiler benchmark) | 1.81 ms | apollo-compiler, 4.01 ms | 2.2x |
| `gql_compiler` | Validate `big_schema_many_fragments` (apollo-compiler benchmark) | 1.17 ms | apollo-compiler, 2.81 ms | 2.4x |
| `gql_compiler` | Parse with syntax error recovery: `many_aliases` (apollo-parser benchmark) | 476 µs | apollo-parser, 2.56 ms | 5.4x |
| `gql_compiler` | Parse with syntax error recovery: the supergraph (apollo-parser benchmark) | 50.9 µs | apollo-parser, 263 µs | 5.2x |
| `gql_normalization` | Normalize an operation (graphql-go-tools benchmark) | 612 ns | graphql-go-tools, 822 ns | 1.34x |
| `gql_normalization` | Minify an operation (graphql-go-tools benchmark) | 12.7 µs | graphql-go-tools, 34.6 µs | 2.72x |
| `gql_normalization` | Fragment spread depth (graphql-go-tools benchmark) | 107 ns | graphql-go-tools, 957 ns | 8.9x |
| `gql_stream` | Publish to 1000 subscribers | 169 µs | graphql-subscriptions, 866 µs | 5.1x |
| `gql_execution` | Subscribe, publish 100 events and execute each | 247 µs | graphql-js, 547 µs | 2.2x |
| `gql_execution` | Execute 100 `@defer` fragments and deliver each payload | 177 µs | graphql-js 17.0.2, 248 µs | 1.40x |
| `gql_execution` | Execute a `@stream` of 1000 items | 333 µs | graphql-js 17.0.2, 993 µs | 2.98x |
| `gql_ws` | Parse a WebSocket frame | 79 ns | tungstenite, 741 ns | 9.4x |
| `gql_ws` | Echo a message over a WebSocket | 7.44 µs | tokio-tungstenite, 10.8 µs | 1.45x |
| `gql_ws_http2` | Echo a message over a WebSocket on HTTP/2 (RFC 8441) | 7.61 µs | h2 with tungstenite, 11.3 µs | 1.49x |
| `gql_ws` | Send 1000 subscription events over graphql-transport-ws | 2.00 µs per event | graphql-ws, 37.7 µs | 18.9x |
| `gql_validation` | Validate the introspection query (graphql-js benchmark) | 40.2 µs | graphql-js, 409 µs | 10.2x |
| `gql_validation` | `many_same_nested_field` (apollo-compiler benchmark) | 694 µs | apollo-compiler, 2.13 ms | 3.1x |
| `gql_validation` | `big_schema_many_fragments` (apollo-compiler benchmark) | 418 µs | apollo-compiler, 3.03 ms | 7.2x |
| `gql_execution` | Execute the introspection query on the GitHub schema (graphql-js benchmark) | 1.82 ms | apollo-compiler, 18.7 ms | 10.3x |
| `gql_execution` | Parse and execute many repeated fields (graphql-js benchmark, no validation) | 17.0 µs | graphql-js, 411 µs | 24x |
| `gql_execution` | Build a client schema from the GitHub introspection result | 2.94 ms | graphql-js, 6.30 ms | 2.1x |
| `gql_client` | Write a 1000-item query result into a new cache | 1.87 ms | Apollo Client, 20.3 ms | 10.8x |
| `gql_client` | Read a 1000-item query from the cache | 1.01 ms | Apollo Client, 13.0 ms | 12.9x |
| `gql_client` | Extract the cache as JSON text | 0.62 ms | Apollo Client, 1.14 ms | 1.84x |
| `gql_client` | Merge 100 deferred chunks into one result | 173 µs | Apollo Client, 423 µs | 2.44x |
| `gql_server` | Execute a small operation | 2.28 µs | Apollo Server, 12.3 µs | 5.4x |
| `gql_server` | Answer an automatic persisted query hit | 2.56 µs | Apollo Server, 9.49 µs | 3.7x |
| `gql_server` | Serve a small POST over HTTP | 26.0 µs | Apollo Server, 160 µs | 6.2x |
| `gql_server` | Execute with a federated trace (`ftv1`) | 20.2 µs | Apollo Server, 84.4 µs | 4.2x |
| `gql_server` | Answer a `@defer` request over `multipart/mixed` | 37.9 µs | Apollo Server, 102 µs | 2.7x |
| `gql_subgraph` | Build a catalog subgraph schema | 414 µs | `@apollo/subgraph`, 3.12 ms | 7.5x |
| `gql_subgraph` | Print the catalog subgraph schema | 36.1 µs | `@apollo/subgraph`, 1.72 ms | 47x |
| `gql_subgraph` | Answer `_service { sdl }` | 1.63 µs | `@apollo/subgraph`, 2.33 µs | 1.43x |
| `gql_subgraph` | Resolve 100 entities | 88.3 µs | `@apollo/subgraph`, 370 µs | 4.2x |
| `gql_mcp` | List 200 operation tools | 593 µs | Apollo MCP Server, 2.24 ms | 3.8x |
| `gql_mcp` | Call an operation tool | 125 µs | Apollo MCP Server, 318 µs | 2.5x |
| `gql_mcp` | Call the search tool | 531 µs | Apollo MCP Server, 3.16 ms | 6.0x |
| `gql_mcp` | Call the introspect tool | 184 µs | Apollo MCP Server, 411 µs | 2.24x |
| `gql_mcp` | Call the validate tool | 65.7 µs | Apollo MCP Server, 241 µs | 3.7x |
| `gql_mcp` | Make a tool from a large operation | 641 µs | Apollo MCP Server, 3.30 ms | 5.2x |
| `gql_codegen` | Generate code for four operations on the GitHub schema | 7.88 ms | Apollo Kotlin, 128 ms | 16x |
| `gql_composition` | Validate the subgraphs of the Netflix DGS example | 8.28 ms | Hive, 31.8 ms | 3.8x |
| `gql_composition` | Validate a huge subgraph schema | 42.5 ms | Hive, 170 ms | 4.0x |
| `gql_router` | Plan the Hive Router benchmark query (`qp_benches.rs`) | 653 µs | Hive Router, 892 µs | 1.37x |
| `gql_router` | Execute the plan of that query against canned subgraph responses | 184 µs | Hive Router, 281 µs | 1.52x |
| `gql_router_stream` | Run one subscription event with an entity fetch (Hive e2e supergraph) | 2.98 µs | Hive Router, 3.39 µs | 1.14x |
| `gql_seamstress` | `supergraph compose` of three subgraphs | 1.22 ms | Hive `composeServices`, 5.43 ms | 4.4x |
| `gql_seamstress` | `graph introspect` of the GitHub schema | 30.1 ms | Rover, 118 ms | 3.9x |
| `gql_seamstress` | `subgraph introspect` of the catalog subgraph | 21.7 ms | Rover, 107 ms | 4.9x |

Each time is one operation: the fastest of 5 rounds of at least one second, after a warm-up. The numbers are from one full run on 2026-10-19, on WSL2 on Windows 11 with 24 hardware threads. Other machines give other times, but the ratios stay close. Each workload compares libraries that do the same work: [Benchmarks](https://github.com/SethKitchen/MojoGraphQL/wiki/Benchmarks#like-for-like) explains the schema builds.

```bash
make bench         # run the benchmarks and write bench/RESULTS.md
make bench-check   # fail when a baseline is faster than Mojo
```

[bench/RESULTS.md](bench/RESULTS.md) holds the latest results. [Benchmarks](https://github.com/SethKitchen/MojoGraphQL/wiki/Benchmarks) explains the method.

## Development

| Command | What it does |
| --- | --- |
| `make check` | Format check, package graph, lint, tests and documentation |
| `make test` | Build and run the test suites; fail a test that takes more than 5 seconds |
| `make lint` | Check docstrings and warnings, as errors |
| `make coverage` | Measure line, branch, condition and MC/DC coverage; fail below 100% |
| `make bench` | Run the benchmarks against the upstream libraries |
| `make bench-check` | Fail when Mojo is not the fastest |
| `make package` | Build precompiled `.mojoc` packages into `dist/` |
| `make fmt` | Format the sources |
| `make packages-check` | Enforce the package graph in `packages.toml` |
| `make docs-check` | Check the documentation writing rules |
| `make clean` | Remove the build outputs |

Add `PKG=<name>` to limit a task to one package. For `test`, `lint` and `coverage`, that is the package and every package that depends on it. All the tools are Mojo programs. The project has no Python.

## License

MojoGraphQL is free for noncommercial use under the [PolyForm Noncommercial License 1.0.0](LICENSE). Commercial use needs a paid license. See [LICENSE-COMMERCIAL.md](LICENSE-COMMERCIAL.md).

The upstream projects are MIT licensed, and their notices are in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). MojoGraphQL ports no Apache-only code and no Elastic licensed code.
