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

The project is new. Today it has eleven finished packages, and more are in progress.

`gql_language` has the lexer, parser, printer and visitor. `gql_json` reads and writes JSON. `gql_schema` holds the type system. `gql_validation` checks operations, and `gql_execution` runs them. `gql_http` is an HTTP/1.1 server and client. `gql_client` is the Apollo Client normalized cache.

`gql_server` is Apollo Server, and `gql_subgraph` builds Apollo Federation subgraphs. `gql_mcp` is the Apollo MCP Server. `gql_codegen` writes Mojo models for operations, as Apollo Kotlin does. `gql_composition` and `gql_router` are in progress.

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
- [x] [`gql_execution`](https://github.com/SethKitchen/MojoGraphQL/wiki/Execution): execution of operations against a schema, with introspection.
- [x] [`gql_http`](https://github.com/SethKitchen/MojoGraphQL/wiki/Http): an HTTP/1.1 server, client and parser, for GraphQL over HTTP.
- [x] [`gql_server`](https://github.com/SethKitchen/MojoGraphQL/wiki/Server): a port of Apollo Server, with the request pipeline, plugins, batching, persisted queries and a standalone server.
- [x] [`gql_subgraph`](https://github.com/SethKitchen/MojoGraphQL/wiki/Subgraph): a port of `@apollo/subgraph` and the Apollo Federation subgraph specification.
- [ ] `gql_composition`: a port of Hive Federation Composition.
- [ ] [`gql_router`](https://github.com/SethKitchen/MojoGraphQL/wiki/Router): a port of Hive Router. The [query planner](https://github.com/SethKitchen/MojoGraphQL/wiki/Router#planner) is done, with the operation cache, [authorization](https://github.com/SethKitchen/MojoGraphQL/wiki/Router#authorization) and [null bubbling](https://github.com/SethKitchen/MojoGraphQL/wiki/Router#null-bubbling). The executor reads subgraph responses, sets request headers, runs plan nodes, and merges each fetch.
- [x] [`gql_client`](https://github.com/SethKitchen/MojoGraphQL/wiki/Client): a port of the Apollo Client normalized cache, `InMemoryCache` with type and field policies.
- [x] [`gql_codegen`](https://github.com/SethKitchen/MojoGraphQL/wiki/Codegen): code generation in the style of Apollo Kotlin. It writes Mojo models for operations.
- [x] [`gql_mcp`](https://github.com/SethKitchen/MojoGraphQL/wiki/Mcp): a port of Apollo MCP Server.
- [ ] `gql_rover`: a port of the MIT parts of the Rover CLI.
- [x] [Compatibility](https://github.com/SethKitchen/MojoGraphQL/wiki/Compatibility): the Apollo Federation subgraph compatibility suite, as tests of `gql_subgraph`. Every check passes except federated tracing (`ftv1`).

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
| `gql_execution` | Done, except async resolvers and subscriptions | `gql_schema`, `gql_json` | graphql-js `src/execution` |
| `gql_http` | Done | nothing | RFC 9110, RFC 9112; GraphQL over HTTP |
| `gql_server` | Done | `gql_validation`, `gql_execution`, `gql_http` | Apollo Server 5.5.1 |
| `gql_subgraph` | Done | `gql_execution` | `@apollo/subgraph` 2.14.4 |
| `gql_composition` | Planned | `gql_validation` | Hive Federation Composition |
| `gql_router` | Query planner done; executor planned | `gql_language`, `gql_json` | Hive Router `1a29df9` `query_planner`, cache, authorization |
| `gql_client` | Done, except optimistic layers | `gql_language`, `gql_json` | Apollo Client 4.3.3 `src/cache` |
| `gql_codegen` | Done, `operationBased` models only | `gql_validation`, `gql_json` | Apollo Kotlin `apollo-compiler` |
| `gql_mcp` | Done | `gql_validation`, `gql_http` | Apollo MCP Server 2.0.0 |
| `gql_rover` | Planned | `gql_composition`, `gql_http` | Rover |

The dependencies of a planned package can change before it is written. `packages.toml` is the record for each package that exists.

## Benchmarks

Mojo is faster than every baseline on every workload except one: building a schema from a parsed AST, where apollo-compiler is faster. Each package with a hot path has a benchmark against its upstream library, on the same fixtures. Mojo must be faster than every baseline.

| Package | Workload | Mojo | Fastest other library | Mojo speedup |
| --- | --- | ---: | --- | ---: |
| `gql_language` | Parse the GitHub schema (368 KB of SDL) | 566 µs | graphql-go-tools, 1.61 ms | 2.85x |
| `gql_language` | Parse the introspection query (graphql-js benchmark) | 4.67 µs | graphql-go-tools, 8.35 µs | 1.79x |
| `gql_language` | Print the kitchen sink (graphql-js benchmark) | 2.62 µs | apollo-compiler, 2.76 µs | 1.05x |
| `gql_language` | Strip ignored characters from the GitHub schema | 755 µs | graphql-js, 5.12 ms | 6.8x |
| `gql_json` | Parse the introspection result | 1.23 ms | Node.js `JSON.parse`, 3.89 ms | 3.2x |
| `gql_json` | Stringify a small response | 1.84 µs | serde_json, 2.49 µs | 1.35x |
| `gql_http` | Parse a request | 197 ns | httparse, 222 ns | 1.12x |
| `gql_http` | Keep-alive request with a JSON body | 9.6 µs | hyper, 11.7 µs | 1.22x |
| `gql_schema` | Parse and build the GitHub schema | 1.07 ms | apollo-compiler, 7.95 ms | 7.4x |
| `gql_schema` | Validate the GitHub schema SDL (graphql-js benchmark) | 3.25 ms | graphql-js, 8.12 ms | 2.5x |
| `gql_schema` | **Build a schema from a parsed AST (graphql-js benchmark)** | **467 µs** | **apollo-compiler, 305 µs** | **0.65x (slower)** |
| `gql_validation` | Validate the introspection query (graphql-js benchmark) | 40.3 µs | graphql-js, 414 µs | 10.3x |
| `gql_validation` | `many_same_nested_field` (apollo-compiler benchmark) | 733 µs | apollo-compiler, 2.09 ms | 2.8x |
| `gql_validation` | `big_schema_many_fragments` (apollo-compiler benchmark) | 441 µs | apollo-compiler, 3.32 ms | 7.5x |
| `gql_execution` | Execute the introspection query on the GitHub schema (graphql-js benchmark) | 1.91 ms | apollo-compiler, 22.0 ms | 11.5x |
| `gql_execution` | Parse and execute many repeated fields (graphql-js benchmark, no validation) | 25.4 µs | graphql-js, 397 µs | 15.6x |
| `gql_execution` | Build a client schema from the GitHub introspection result | 3.01 ms | graphql-js, 7.46 ms | 2.5x |
| `gql_client` | Write a 1000-item query result into a new cache | 1.89 ms | Apollo Client, 20.3 ms | 10.8x |
| `gql_client` | Read a 1000-item query from the cache | 1.01 ms | Apollo Client, 12.9 ms | 12.9x |
| `gql_client` | Extract the cache as JSON text | 0.63 ms | Apollo Client, 1.18 ms | 1.86x |
| `gql_server` | Execute a small operation | 10.7 µs | Apollo Server, 99.4 µs | 9.3x |
| `gql_server` | Answer an automatic persisted query hit | 14.1 µs | Apollo Server, 59.8 µs | 4.2x |
| `gql_server` | Serve a small POST over HTTP | 54.9 µs | Apollo Server, 943 µs | 17.2x |
| `gql_subgraph` | Build a catalog subgraph schema | 410 µs | `@apollo/subgraph`, 5.46 ms | 13.3x |
| `gql_subgraph` | Print the catalog subgraph schema | 35.7 µs | `@apollo/subgraph`, 1.87 ms | 52x |
| `gql_subgraph` | Answer `_service { sdl }` | 1.63 µs | `@apollo/subgraph`, 2.41 µs | 1.48x |
| `gql_subgraph` | Resolve 100 entities | 91.2 µs | `@apollo/subgraph`, 380 µs | 4.2x |
| `gql_mcp` | List 200 operation tools | 644 µs | Apollo MCP Server, 2.45 ms | 3.8x |
| `gql_mcp` | Call an operation tool | 128 µs | Apollo MCP Server, 365 µs | 2.85x |
| `gql_mcp` | Call the search tool | 548 µs | Apollo MCP Server, 3.30 ms | 6.0x |
| `gql_mcp` | Call the introspect tool | 191 µs | Apollo MCP Server, 465 µs | 2.44x |
| `gql_mcp` | Call the validate tool | 69.2 µs | Apollo MCP Server, 264 µs | 3.8x |
| `gql_mcp` | Make a tool from a large operation | 722 µs | Apollo MCP Server, 3.34 ms | 4.6x |
| `gql_codegen` | Generate code for four operations on the GitHub schema | 9.31 ms | Apollo Kotlin, 139 ms | 15x |
| `gql_router` | Plan the Hive Router benchmark query (`qp_benches.rs`) | 667 µs | Hive Router, 912 µs | 1.37x |

Each time is one operation: the fastest of 5 rounds of at least one second, after a warm-up. The numbers are from 2026-10-15 to 2026-10-18, on WSL2 on Windows 11 with 24 hardware threads. Other machines give other times, but the ratios stay close. The open gap is a known item: apollo-compiler builds its schema from an AST that its slower parser already prepared.

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
