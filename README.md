<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# MojoGraphQL

[![Mojo 1.2.0](https://img.shields.io/badge/Mojo-1.2.0-orange)](https://docs.modular.com/mojo/)
[![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue)](LICENSE)
[![Coverage requirement: 100% line, branch, condition, MC/DC](https://img.shields.io/badge/coverage%20requirement-100%25%20line%20%7C%20branch%20%7C%20condition%20%7C%20MC%2FDC-informational)](https://github.com/SethKitchen/MojoGraphQL/wiki/Coverage-tool)
[![Benchmark requirement: faster than upstream](https://img.shields.io/badge/benchmark%20requirement-faster%20than%20upstream-informational)](https://github.com/SethKitchen/MojoGraphQL/wiki/Benchmarks)

MojoGraphQL is a GraphQL library written from scratch in Mojo. It ports MIT licensed GraphQL projects: graphql-js, apollo-rs, Apollo Server, Apollo Client, Hive Router and others. Each part is a separate Mojo package, so you install only the parts that you need. Each port must be faster than its upstream, and a benchmark proves it.

The project has thirty-three finished packages.

`gql_language` has the lexer, parser, printer and visitor. `gql_json` reads and writes JSON. `gql_schema` holds the type system. `gql_validation` checks operations, and `gql_execution` runs them. `gql_http` is an HTTP/1.1 server and client. `gql_client` is the Apollo Client normalized cache.

`gql_server` is Apollo Server, and `gql_subgraph` builds Apollo Federation subgraphs. `gql_mcp` is the Apollo MCP Server. `gql_codegen` writes Mojo models for operations, as Apollo Kotlin does. `gql_composition` composes a supergraph, and `seamstress` (`gql_seamstress`) runs the offline Rover commands. `gql_router` plans and runs federated operations over a supergraph. `gql_http2`, `gql_tls` and `gql_http3` serve HTTP/2, HTTPS and HTTP/3, and fall back to what the network supports.

Subscriptions and streams go through the whole stack. `gql_stream` holds the event streams. `gql_execution` runs subscriptions and `@defer`/`@stream`. `gql_ws` and `gql_sse` carry them over WebSocket and Server-Sent Events, and `gql_http` streams `multipart/mixed`. `gql_ws_http2` and `gql_ws_http3` run WebSockets over HTTP/2 and HTTP/3. The client tries HTTP/3, then HTTP/2, then HTTP/1.1.

`gql_server_ws` adds subscriptions to `gql_server`, and `gql_router_stream` adds subscriptions and streamed `@defer` to `gql_router`. A user who needs no streams does not build these packages.

`gql_scorchql` is ScorchQL, a federated gateway. Subgraphs publish to it, and it composes them and serves the supergraph with `gql_router`. Its web explorer shows the schema, runs operations and draws query plans.

`gql_forge` is Forge, a control plane for those graphs. People and companies register the endpoints that they already host. Forge does not host the graphs. It stores telemetry, compares environments, and answers questions about the schemas.

The [feature checklist](#features) shows what is done and what is planned.

## Install

You need Linux on x86-64 or aarch64, macOS on Apple Silicon, or Windows with WSL 2. You also need [uv](https://docs.astral.sh/uv/) to install the Mojo toolchain.

```bash
git clone https://github.com/SethKitchen/MojoGraphQL.git
cd MojoGraphQL
uv venv && uv pip install "mojo==1.2.0"
make check
```

The toolchain is pinned to Mojo `1.2.0` (`2016d0cd`). Other Mojo versions do not work. See [How to install](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-install) for the details and for Windows.

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
- [How to host a gateway](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-host-a-gateway): run ScorchQL, publish subgraphs, and open its explorer.
- [How to run Forge](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-run-Forge): start Forge and register a customer-hosted supergraph.
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
- [x] [Introspection and `buildClientSchema`](https://github.com/SethKitchen/MojoGraphQL/wiki/Schema#introspection-and-client-schemas)

### Packages

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
- [x] [`gql_scorchql`](https://github.com/SethKitchen/MojoGraphQL/wiki/ScorchQL): ScorchQL, a federated gateway. It keeps a registry of published subgraphs, composes them on each publish, and reloads every worker without a restart. Its web explorer builds operations, runs them and draws query plans.
- [x] [`gql_forge`](https://github.com/SethKitchen/MojoGraphQL/wiki/Forge): Forge, a control plane for customer-hosted supergraphs. It records endpoints, pulls or stores schemas, compares environments, ingests telemetry and answers questions about the graph.
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
| `gql_schema` | Done | `gql_language`, `gql_json` | graphql-js `src/type`, `src/utilities` |
| `gql_validation` | Done | `gql_schema` | graphql-js `src/validation` |
| `gql_execution` | Done | `gql_schema`, `gql_json`, `gql_stream` | graphql-js 16.14.2 `src/execution`; graphql-js 17.0.2 incremental delivery |
| `gql_http` | Done | nothing | RFC 9110, RFC 9112; GraphQL over HTTP |
| `gql_sse` | Done | `gql_http`, `gql_json`, `gql_stream` | graphql-sse 2.6.3 |
| `gql_sse_execution` | Done | `gql_sse`, `gql_execution`, `gql_validation` | graphql-sse 2.6.3 `handler.ts` |
| `gql_stream` | Done | `gql_json` | graphql-subscriptions PubSub and `withFilter` |
| `gql_ws` | Done | `gql_http`, `gql_stream` | RFC 6455; graphql-ws `graphql-transport-ws`; tungstenite |
| `gql_ws_execution` | Done | `gql_ws`, `gql_execution`, `gql_validation` | graphql-ws `useServer` |
| `gql_ws_http2` | Done | `gql_ws`, `gql_http2` | RFC 8441; h2 0.4.20 extended CONNECT |
| `gql_ws_http3` | Done | `gql_ws_http2`, `gql_http3` | RFC 9220; hyperium/h3 extended CONNECT |
| `gql_http2` | Done | `gql_http` | hyperium/h2 0.4.20; RFC 9113, RFC 7541 |
| `gql_tls` | Done | `gql_http`; system OpenSSL 3 at run time | RFC 8446, RFC 7301 |
| `gql_https2` | Done | `gql_tls`, `gql_http2` | RFC 9113 over TLS; RFC 7301 |
| `gql_quic` | Done | `gql_tls`; system OpenSSL 3.5 at run time | quinn-proto 0.11.19; RFC 9000, RFC 9001, RFC 9002 |
| `gql_http3` | Done | `gql_quic`, `gql_https2`; OpenSSL 3.5 at run time | hyperium/h3; RFC 9114, RFC 9204 |
| `gql_server` | Done | `gql_validation`, `gql_execution`, `gql_http`, `gql_stream` | Apollo Server 5.5.1 |
| `gql_server_ws` | Done | `gql_server`, `gql_ws_execution` | Apollo Server 5.5.1 subscriptions with graphql-ws |
| `gql_subgraph` | Done | `gql_execution` | `@apollo/subgraph` 2.14.4 |
| `gql_composition` | Done | `gql_language` | Hive Federation Composition v0.27.0 |
| `gql_router` | Done | `gql_language`, `gql_json`, `gql_http`, `gql_validation` | Hive Router `1a29df9` query planner, executor and pipeline |
| `gql_router_stream` | Done | `gql_router`, `gql_ws`, `gql_stream` | Hive Router `1a29df9` subscriptions; streamed `@defer` |
| `gql_client` | Done | `gql_language`, `gql_json` | Apollo Client 4.3.3 `src/cache`, `src/incremental` |
| `gql_client_http` | Done | `gql_http`, `gql_json` | Apollo Client 4.3.3 `parseAndCheckHttpResponse.ts` |
| `gql_codegen` | Done | `gql_validation`, `gql_json` | Apollo Kotlin `apollo-compiler` |
| `gql_compiler` | Done | `gql_language` | apollo-compiler 1.33.0 (apollo-rs) |
| `gql_normalization` | Done | `gql_schema`, `gql_json` | graphql-go-tools v2 `astnormalization`, `astminify`, `variablesvalidation` |
| `gql_mcp` | Done | `gql_validation`, `gql_http` | Apollo MCP Server 2.0.0 |
| `gql_seamstress` | Done | `gql_composition`, `gql_execution`, `gql_http` | Rover 1.0.0, MIT parts |
| `gql_scorchql` | Done | `gql_router_stream`, `gql_composition`, `gql_ws` | None: original work |
| `gql_forge` | Done | `gql_schema`, `gql_http` | None: original work |

The dependencies of a planned package can change before it is written. `packages.toml` is the record for each package that exists.

## Benchmarks

Mojo is faster than every baseline on every workload. Each package with a hot path has a benchmark against its upstream library, on the same fixtures. Mojo must be faster than every baseline.

| Package | Workload | Mojo 1.2 | Mojo 1.1 | Fastest other library | Mojo speedup |
| --- | --- | ---: | ---: | --- | ---: |
| `gql_language` | Parse the GitHub schema (368 KB of SDL) | 1.03 ms | 1.02 ms | graphql-go-tools, 3.07 ms | 2.98x |
| `gql_language` | Parse the introspection query (graphql-js benchmark) | 7.76 µs | 8.00 µs | graphql-go-tools, 13.9 µs | 1.79x |
| `gql_language` | Print the kitchen sink (graphql-js benchmark) | 4.29 µs | 4.23 µs | apollo-compiler, 4.37 µs | 1.02x |
| `gql_language` | Strip ignored characters from the GitHub schema | 1.40 ms | 1.38 ms | graphql-js, 6.80 ms | 4.8x |
| `gql_json` | Parse the introspection result | 2.63 ms | 2.55 ms | Node.js `JSON.parse`, 6.17 ms | 2.34x |
| `gql_json` | Stringify a small response | 3.00 µs | 3.17 µs | astjson, 4.44 µs | 1.48x |
| `gql_http` | Parse a request | 412 ns | 409 ns | httparse, 417 ns | 1.01x |
| `gql_http` | Keep-alive request with a JSON body | 7.76 µs | 7.79 µs | hyper, 12.2 µs | 1.57x |
| `gql_http` | Stream a chunked response of 16 parts | 8.68 µs | 8.97 µs | hyper, 22.5 µs | 2.59x |
| `gql_http` | Parse a `multipart/mixed` body of 100 parts | 200 µs | 201 µs | meros, 737 µs | 3.68x |
| `gql_sse` | Subscribe and send 1000 `next` events | 1.93 ms | 2.01 ms | graphql-sse, 7.30 ms | 3.79x |
| `gql_sse` | Parse 1000 `next` events | 867 µs | 869 µs | graphql-sse, 1.98 ms | 2.29x |
| `gql_http2` | HPACK encode a GraphQL request header block | 1.54 µs | 1.52 µs | h2, 1.78 µs | 1.15x |
| `gql_http2` | HPACK decode the same block | 1.62 µs | 1.63 µs | h2, 3.29 µs | 2.04x |
| `gql_http2` | h2c round trip with a small JSON body | 27.5 µs | 27.4 µs | hyper and h2, 35.1 µs | 1.28x |
| `gql_tls` | TLS keep-alive request round trip | 36.8 µs | 37.7 µs | hyper and rustls, 37.9 µs | 1.03x |
| `gql_https2` | h2 over TLS round trip with a small JSON body | 43.2 µs | 57.6 µs | hyper, h2 and rustls, 67.7 µs | 1.57x |
| `gql_quic` | Echo 32 bytes on one QUIC stream | 40.6 µs | 41.2 µs | quinn, 45.2 µs | 1.11x |
| `gql_http3` | QPACK encode a request header block | 1.35 µs | 1.30 µs | h3, 4.05 µs | 3.01x |
| `gql_http3` | QPACK decode a request header block | 1.49 µs | 1.50 µs | h3, 4.18 µs | 2.80x |
| `gql_http3` | HTTP/3 round trip with a small JSON body | 48.1 µs | 47.9 µs | h3 and quinn, 69.7 µs | 1.45x |
| `gql_schema` | Parse and build the GitHub schema | 2.00 ms | 2.00 ms | apollo-compiler, 14.6 ms | 7.33x |
| `gql_schema` | Validate the GitHub schema SDL (graphql-js benchmark) | 5.58 ms | 6.10 ms | graphql-js, 14.6 ms | 2.62x |
| `gql_schema` | Build a schema from a parsed AST, as graphql-js `buildASTSchema` (graphql-js benchmark) | 874 µs | 885 µs | graphql-js, 9.04 ms | 10.4x |
| `gql_compiler` | Build a schema from a parsed AST, as apollo-compiler `Schema::from_ast` | 419 µs | 426 µs | apollo-compiler, 599 µs | 1.43x |
| `gql_compiler` | Build the GitHub query against the GitHub schema | 75.6 µs | 76.1 µs | apollo-compiler, 158 µs | 2.09x |
| `gql_compiler` | Print the GitHub schema, as apollo-compiler `Schema::to_string` | 876 µs | 887 µs | apollo-compiler, 1.51 ms | 1.72x |
| `gql_compiler` | Validate `many_arguments` (apollo-compiler benchmark) | 3.16 ms | 3.24 ms | apollo-compiler, 7.37 ms | 2.33x |
| `gql_compiler` | Validate `big_schema_many_fragments` (apollo-compiler benchmark) | 2.28 ms | 2.31 ms | apollo-compiler, 8.52 ms | 3.73x |
| `gql_compiler` | Parse with syntax error recovery: `many_aliases` (apollo-parser benchmark) | 838 µs | 819 µs | apollo-parser, 4.44 ms | 5.30x |
| `gql_compiler` | Parse with syntax error recovery: the supergraph (apollo-parser benchmark) | 89.7 µs | 85.0 µs | apollo-parser, 432 µs | 4.81x |
| `gql_normalization` | Normalize an operation (graphql-go-tools benchmark) | 900 ns | 927 ns | graphql-go-tools, 1.17 µs | 1.30x |
| `gql_normalization` | Minify an operation (graphql-go-tools benchmark) | 22.0 µs | 22.0 µs | graphql-go-tools, 56.9 µs | 2.59x |
| `gql_normalization` | Fragment spread depth (graphql-go-tools benchmark) | 171 ns | 176 ns | graphql-go-tools, 1.42 µs | 8.28x |
| `gql_stream` | Publish to 1000 subscribers | 330 µs | 319 µs | graphql-subscriptions, 1.77 ms | 5.37x |
| `gql_execution` | Subscribe, publish 100 events and execute each | 375 µs | 389 µs | graphql-js, 1.19 ms | 3.19x |
| `gql_execution` | Execute 100 `@defer` fragments and deliver each payload | 277 µs | 278 µs | graphql-js 17.0.2, 422 µs | 1.52x |
| `gql_execution` | Execute a `@stream` of 1000 items | 551 µs | 562 µs | graphql-js 17.0.2, 1.83 ms | 3.32x |
| `gql_ws` | Parse a WebSocket frame | 143 ns | 146 ns | tungstenite, 2.83 µs | 19.8x |
| `gql_ws` | Echo a message over a WebSocket | 6.53 µs | 6.45 µs | tokio-tungstenite, 16.5 µs | 2.53x |
| `gql_ws_http2` | Echo a message over a WebSocket on HTTP/2 (RFC 8441) | 6.99 µs | 7.11 µs | h2 with tungstenite, 17.3 µs | 2.47x |
| `gql_ws` | Send 1000 subscription events over graphql-transport-ws | 2.53 µs per event | 2.58 µs per event | graphql-ws, 25.3 µs | 10.0x |
| `gql_validation` | Validate the introspection query (graphql-js benchmark) | 68.7 µs | 69.3 µs | graphql-js, 719 µs | 10.5x |
| `gql_validation` | `many_same_nested_field` (apollo-compiler benchmark) | 1.28 ms | 1.26 ms | apollo-compiler, 3.74 ms | 2.92x |
| `gql_validation` | `big_schema_many_fragments` (apollo-compiler benchmark) | 731 µs | 748 µs | apollo-compiler, 8.48 ms | 11.6x |
| `gql_execution` | Execute the introspection query on the GitHub schema (graphql-js benchmark) | 4.12 ms | 4.13 ms | apollo-compiler, 35.9 ms | 8.71x |
| `gql_execution` | Parse and execute many repeated fields (graphql-js benchmark, no validation) | 28.2 µs | 28.7 µs | graphql-js, 249 µs | 8.85x |
| `gql_execution` | Build a client schema from the GitHub introspection result | 5.67 ms | 5.81 ms | graphql-js, 12.2 ms | 2.15x |
| `gql_client` | Write a 1000-item query result into a new cache | 3.33 ms | 3.37 ms | Apollo Client, 43.8 ms | 13.2x |
| `gql_client` | Read a 1000-item query from the cache | 1.72 ms | 1.71 ms | Apollo Client, 25.5 ms | 14.9x |
| `gql_client` | Extract the cache as JSON text | 1.14 ms | 1.11 ms | Apollo Client, 1.95 ms | 1.72x |
| `gql_client` | Merge 100 deferred chunks into one result | 306 µs | 311 µs | Apollo Client, 752 µs | 2.45x |
| `gql_server` | Execute a small operation | 4.25 µs | 4.26 µs | Apollo Server, 27.5 µs | 6.48x |
| `gql_server` | Answer an automatic persisted query hit | 5.10 µs | 5.22 µs | Apollo Server, 21.1 µs | 4.14x |
| `gql_server` | Serve a small POST over HTTP | 23.6 µs | 23.8 µs | Apollo Server, 234 µs | 9.91x |
| `gql_server` | Execute with a federated trace (`ftv1`) | 33.5 µs | 34.1 µs | Apollo Server, 167 µs | 4.98x |
| `gql_server` | Answer a `@defer` request over `multipart/mixed` | 64.0 µs | 63.3 µs | Apollo Server, 199 µs | 3.12x |
| `gql_subgraph` | Build a catalog subgraph schema | 711 µs | 766 µs | `@apollo/subgraph`, 9.03 ms | 12.7x |
| `gql_subgraph` | Print the catalog subgraph schema | 61.2 µs | 61.9 µs | `@apollo/subgraph`, 4.10 ms | 67x |
| `gql_subgraph` | Answer `_service { sdl }` | 3.00 µs | 2.94 µs | `@apollo/subgraph`, 4.88 µs | 1.63x |
| `gql_subgraph` | Resolve 100 entities | 167 µs | 166 µs | `@apollo/subgraph`, 565 µs | 3.38x |
| `gql_mcp` | List 200 operation tools | 732 µs | 727 µs | Apollo MCP Server, 4.78 ms | 6.53x |
| `gql_mcp` | Call an operation tool | 52.9 µs | 54.1 µs | Apollo MCP Server, 244 µs | 4.62x |
| `gql_mcp` | Call the search tool | 963 µs | 962 µs | Apollo MCP Server, 6.26 ms | 6.50x |
| `gql_mcp` | Call the introspect tool | 240 µs | 264 µs | Apollo MCP Server, 650 µs | 2.71x |
| `gql_mcp` | Call the validate tool | 43.2 µs | 43.6 µs | Apollo MCP Server, 246 µs | 5.70x |
| `gql_mcp` | Make a tool from a large operation | 1.16 ms | 1.16 ms | Apollo MCP Server, 6.16 ms | 5.32x |
| `gql_codegen` | Generate code for four operations on the GitHub schema | 8.25 ms | 8.59 ms | Apollo Kotlin, 463 ms | 56x |
| `gql_composition` | Validate the subgraphs of the Netflix DGS example | 15.0 ms | 16.0 ms | Hive, 55.9 ms | 3.72x |
| `gql_composition` | Validate a huge subgraph schema | 71.5 ms | 74.8 ms | Hive, 331 ms | 4.63x |
| `gql_router` | Plan the Hive Router benchmark query (`qp_benches.rs`) | 1.12 ms | 1.15 ms | Hive Router, 1.54 ms | 1.37x |
| `gql_router` | Execute the plan of that query against canned subgraph responses | 332 µs | 336 µs | Hive Router, 464 µs | 1.40x |
| `gql_router_stream` | Run one subscription event with an entity fetch (Hive e2e supergraph) | 4.84 µs | 5.07 µs | Hive Router, 6.83 µs | 1.41x |
| `gql_seamstress` | `supergraph compose` of three subgraphs | 2.21 ms | 2.23 ms | Hive `composeServices`, 11.3 ms | 5.12x |
| `gql_seamstress` | `graph introspect` of the GitHub schema | 25.4 ms | 25.7 ms | Rover, 39.3 ms | 1.55x |
| `gql_seamstress` | `subgraph introspect` of the catalog subgraph | 12.3 ms | 12.1 ms | Rover, 23.1 ms | 1.87x |

Each time is one operation: the fastest of 5 rounds of at least one second, after a warm-up. The numbers are from one full run on 2026-10-23, on Linux with an Intel N150 and 4 hardware threads. Both Mojo 1.2.0 and Mojo 1.1.0 are measured on the same machine. Other machines give other times, but the ratios stay close. Each workload compares libraries that do the same work: [Benchmarks](https://github.com/SethKitchen/MojoGraphQL/wiki/Benchmarks#like-for-like) explains the schema builds.

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
